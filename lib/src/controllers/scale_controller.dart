import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:usb_serial/usb_serial.dart';

import '../models/scale_state.dart';

final scaleControllerProvider =
    StateNotifierProvider<ScaleController, ScaleState>((ref) {
      final controller = ScaleController();
      ref.onDispose(controller.dispose);
      controller.initialize();
      return controller;
    });

class ScaleController extends StateNotifier<ScaleState> {
  ScaleController() : super(ScaleState.initial());

  static const double _noiseThreshold = 0.003;

  UsbPort? _port;
  StreamSubscription<Uint8List>? _inputSubscription;
  StreamSubscription<UsbEvent>? _usbEventSubscription;
  bool _isConnecting = false;
  final StringBuffer _pendingLine = StringBuffer();
  double? _lastNumericWeight;
  double? _pendingWeight;
  int _pendingWeightHits = 0;

  void initialize() {
    _log('ScaleController init');
    _usbEventSubscription = UsbSerial.usbEventStream?.listen((event) {
      _log('USB event: ${event.event}');
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        refresh();
      } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        _handleDetached();
      }
    });
    refresh();
  }

  Future<void> refresh() async {
    _setStatus(
      ScaleStatus.searching,
      'กำลังค้นหาเครื่องชั่ง...',
      busy: true,
      targetWeight: null,
    );

    if (_isConnecting) return;
    _isConnecting = true;

    await _closePort();

    try {
      final devices = await UsbSerial.listDevices();
      _log('Detected ${devices.length} USB devices');
      final candidates = _selectDevices(devices);

      if (candidates.isEmpty) {
        _setStatus(
          ScaleStatus.waitingUsb,
          'กรุณาเสียบเครื่องชั่งผ่าน USB',
          busy: false,
          targetWeight: null,
        );
        return;
      }

      UsbPort? port;
      for (final device in candidates) {
        _log('Attempting to use device ${device.deviceName}');
        final newPort = await _createPort(device);
        if (newPort == null) {
          _log('Skipping device ${device.deviceName}');
          continue;
        }
        if (!await newPort.open()) {
          _log('Failed to open ${device.deviceName}');
          try {
            await newPort.close();
          } catch (_) {}
          continue;
        }

        port = newPort;
        break;
      }

      if (port == null) {
        _setStatus(
          ScaleStatus.error,
          'เปิดพอร์ต USB ไม่ได้',
          busy: false,
          targetWeight: null,
        );
        return;
      }

      await port.setDTR(true);
      await port.setRTS(true);
      await port.setPortParameters(
        9600,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      final inputStream = port.inputStream;
      if (inputStream == null) {
        await port.close();
        _setStatus(
          ScaleStatus.error,
          'อุปกรณ์ไม่ส่งข้อมูล',
          busy: false,
          targetWeight: null,
        );
        return;
      }

      _inputSubscription = inputStream.listen(
        _handleChunk,
        onError: (error) => _handleError('อ่านข้อมูลไม่ได้: $error'),
        onDone: () => _handleError('การเชื่อมต่อถูกปิด'),
      );

      _port = port;
      _setStatus(
        ScaleStatus.connected,
        'เชื่อมต่อแล้ว',
        busy: false,
        targetWeight: state.targetWeight,
      );
    } catch (e, st) {
      _log('initUsb error: $e\n$st');
      _handleError('เกิดข้อผิดพลาด: $e');
    } finally {
      _isConnecting = false;
    }
  }

  List<UsbDevice> _selectDevices(List<UsbDevice> devices) {
    final primary = <UsbDevice>[];
    final secondary = <UsbDevice>[];
    for (final device in devices) {
      final vid = device.vid;
      final pid = device.pid;
      if (vid == null || pid == null) continue;
      if (vid == 0x1A86 && pid == 0x7523) {
        primary.add(device);
      } else if (vid == 0x0483 && pid == 0x5743) {
        secondary.add(device);
      }
    }
    return [...primary, ...secondary];
  }

  Future<UsbPort?> _createPort(UsbDevice device) async {
    final vid = device.vid ?? -1;
    final type = vid == 0x1A86 ? UsbSerial.CH34x : '';
    try {
      return await device.create(type);
    } on PlatformException catch (e, st) {
      _log('createPort failed: ${e.message}\n$st');
      return null;
    }
  }

  Future<void> _closePort() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    if (_port != null) {
      try {
        await _port!.close();
      } catch (_) {}
    }
    _port = null;
    _pendingLine.clear();
    _pendingWeight = null;
    _pendingWeightHits = 0;
  }

  void _handleChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;
    for (final byte in chunk) {
      if (byte == 10 || byte == 13) {
        if (_pendingLine.isEmpty) continue;
        final line = _pendingLine.toString();
        _pendingLine.clear();
        _handleLine(line.trim());
        continue;
      }

      if (byte < 32 && byte != 9) continue;
      _pendingLine.writeCharCode(byte);
    }
  }

  void _handleLine(String line) {
    if (line.isEmpty) return;
    final match = RegExp(r'[+-]?\d+(?:\.\d+)?').firstMatch(line.trim());
    if (match == null) return;

    final valueText = match.group(0)?.replaceFirst('+', '');
    if (valueText == null) return;

    final value = double.tryParse(valueText);
    if (value == null) return;

    if (_lastNumericWeight == null) {
      _commitWeight(value);
      return;
    }

    final deltaFromCurrent = (value - _lastNumericWeight!).abs();
    if (deltaFromCurrent < _noiseThreshold) {
      _pendingWeight = null;
      _pendingWeightHits = 0;
      return;
    }

    if (_pendingWeight == null ||
        (value - _pendingWeight!).abs() >= _noiseThreshold) {
      _pendingWeight = value;
      _pendingWeightHits = 1;
      return;
    }

    _pendingWeightHits += 1;
    if (_pendingWeightHits >= 2) {
      _pendingWeight = null;
      _pendingWeightHits = 0;
      _commitWeight(value);
    }
  }

  void _handleDetached() {
    _closePort();
    _lastNumericWeight = null;
    _setStatus(
      ScaleStatus.disconnected,
      'เครื่องชั่งถูกถอดออก',
      busy: false,
      targetWeight: null,
    );
  }

  void _handleError(String message) {
    _closePort();
    _lastNumericWeight = null;
    _setStatus(ScaleStatus.error, message, busy: false, targetWeight: null);
  }

  void _commitWeight(double value) {
    _lastNumericWeight = value;
    _setStatus(
      ScaleStatus.connected,
      'เชื่อมต่อแล้ว',
      busy: false,
      targetWeight: value,
    );
  }

  void _setStatus(
    ScaleStatus status,
    String text, {
    bool? busy,
    double? targetWeight,
  }) {
    state = state.copyWith(
      status: status,
      statusText: text,
      isBusy: busy ?? state.isBusy,
      targetWeight: targetWeight,
    );
  }

  @override
  void dispose() {
    _usbEventSubscription?.cancel();
    _inputSubscription?.cancel();
    _port?.close();
    super.dispose();
  }

  void _log(String message) {
    debugPrint('[ScaleController] $message');
  }
}

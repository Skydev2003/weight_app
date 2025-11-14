import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(home: ScalePage()));
}

class ScalePage extends StatefulWidget {
  const ScalePage({super.key});

  @override
  State<ScalePage> createState() => _ScalePageState();
}

class _ScalePageState extends State<ScalePage> {
  static const _scaleStream = EventChannel('scale_usb_stream');

  String? _weight;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _scaleStream.receiveBroadcastStream().listen(
      (event) {
        setState(() {
          // event = string น้ำหนัก หรือ null ถ้าไม่เจอเครื่องชั่ง
          _weight = event as String?;
        });
      },
      onError: (err) {
        setState(() {
          _weight = null;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _weight == null ? '— ไม่พบเครื่องชั่ง —' : '$_weight kg';

    return Scaffold(
      appBar: AppBar(title: const Text('Scale USB Realtime')),
      body: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

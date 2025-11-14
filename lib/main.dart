import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ScalePage()));
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
  String _debug = 'Starting...';

  @override
  void initState() {
    super.initState();

    setState(() {
      _debug = 'Listening to stream...';
    });

    _sub = _scaleStream.receiveBroadcastStream().listen(
      (event) {
        setState(() {
          _debug = 'Received: $event';
          _weight = event as String?;
        });
      },
      onError: (err) {
        setState(() {
          _debug = 'Error: $err';
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
    final text = _weight == null ? 'ไม่พบเครื่องชั่ง' : '$_weight kg';

    return Scaffold(
      appBar: AppBar(title: const Text('Scale USB Realtime')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              'Debug: $_debug',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

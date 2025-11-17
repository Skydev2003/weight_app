import 'package:flutter/material.dart';

import '../models/scale_state.dart';

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({required this.state, super.key});

  final ScaleState state;

  Color get _statusColor {
    switch (state.status) {
      case ScaleStatus.connected:
        return const Color(0xFF64ff51);
      case ScaleStatus.searching:
      case ScaleStatus.waitingUsb:
        return Colors.amberAccent;
      case ScaleStatus.disconnected:
      case ScaleStatus.error:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            state.statusText,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.state, super.key});

  final ScaleState state;

  IconData get _icon {
    switch (state.status) {
      case ScaleStatus.connected:
        return Icons.usb;
      case ScaleStatus.waitingUsb:
        return Icons.usb_off;
      case ScaleStatus.disconnected:
        return Icons.cable;
      case ScaleStatus.searching:
        return Icons.search;
      case ScaleStatus.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: Colors.white),
          const SizedBox(width: 12),
          Text(state.statusText, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class WeightDisplayCard extends StatelessWidget {
  const WeightDisplayCard({
    required this.weightText,
    required this.isConnected,
    required this.statusText,
    super.key,
  });

  final String weightText;
  final bool isConnected;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: 0.6),
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: [
            Icon(
              isConnected ? Icons.scale : Icons.usb_off,
              color: const Color(0xFF64ff51),
              size: 56,
            ),
            const SizedBox(height: 20),
            Text(
              weightText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isConnected ? 72 : 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isConnected ? 'กิโลกรัม' : statusText,
              style: const TextStyle(fontSize: 24, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ActionPanel extends StatelessWidget {
  const ActionPanel({
    required this.onRefresh,
    required this.disabled,
    required this.state,
    super.key,
  });

  final VoidCallback onRefresh;
  final bool disabled;
  final ScaleState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: disabled ? null : onRefresh,
            icon: const Icon(Icons.sync),
            label: Text(disabled ? 'กำลังเชื่อมต่อ...' : 'เชื่อมต่ออีกครั้ง'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: disabled ? null : onRefresh,
            icon: const Icon(Icons.auto_awesome),
            label: Text(_hintForStatus(state.status)),
          ),
        ),
      ],
    );
  }

  static String _hintForStatus(ScaleStatus status) {
    switch (status) {
      case ScaleStatus.connected:
        return 'รีเฟรชค่า';
      case ScaleStatus.searching:
        return 'กำลังค้นหา';
      case ScaleStatus.waitingUsb:
        return 'เสียบ USB';
      case ScaleStatus.disconnected:
        return 'เชื่อมต่อใหม่';
      case ScaleStatus.error:
        return 'ลองใหม่';
    }
  }
}

class ReconnectBanner extends StatelessWidget {
  const ReconnectBanner({required this.isVisible, super.key});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Visibility(
        visible: isVisible,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: const [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'กำลังเชื่อมต่อใหม่กับเครื่องชั่ง...',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({required this.state, super.key});

  final ScaleState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'สถานะการเชื่อมต่อ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              state.statusText,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  state.status == ScaleStatus.connected
                      ? Icons.check_circle
                      : Icons.pending,
                  color: Colors.white54,
                ),
                const SizedBox(width: 8),
                Text(
                  state.isBusy ? 'กำลังรีโหลด...' : 'พร้อมทำงาน',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

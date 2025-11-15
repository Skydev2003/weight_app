import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/scale_controller.dart';
import 'widgets/scale_widgets.dart';

class ScalePage extends ConsumerStatefulWidget {
  const ScalePage({super.key});

  @override
  ConsumerState<ScalePage> createState() => _ScalePageState();
}

class _ScalePageState extends ConsumerState<ScalePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _weightController;
  Animation<double>? _weightAnimation;
  double _displayWeight = 0;

  @override
  void initState() {
    super.initState();
    _weightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _weightController.addListener(() {
      final value = _weightAnimation?.value;
      if (value == null || !mounted) return;
      setState(() => _displayWeight = value);
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ScaleState>(scaleControllerProvider, (previous, next) {
      _handleWeightChange(previous?.targetWeight, next.targetWeight);
      if (next.targetWeight == null && previous?.targetWeight != null) {
        _resetAnimation();
      }
    });

    final state = ref.watch(scaleControllerProvider);
    final controller = ref.read(scaleControllerProvider.notifier);

    final hasWeight = state.targetWeight != null;
    final weightText =
        hasWeight ? _formatWeight(_displayWeight) : 'ไม่พบเครื่องชั่ง';

    return Scaffold(
      appBar: AppBar(
        title: const Text('เครื่องชั่ง USB'),
        actions: [
          StatusIndicator(state: state),
          IconButton(
            tooltip: 'เชื่อมต่อใหม่',
            onPressed: state.isBusy ? null : controller.refresh,
            icon: state.isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF071307),
              Color(0xFF0c1c0c),
              Color(0xFF041003),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReconnectBanner(isVisible: state.isBusy),
                    const SizedBox(height: 20),
                    StatusChip(state: state),
                    const SizedBox(height: 24),
                    WeightDisplayCard(
                      weightText: weightText,
                      isConnected: hasWeight,
                      statusText: state.statusText,
                    ),
                    const SizedBox(height: 24),
                    ActionPanel(
                      onRefresh: controller.refresh,
                      disabled: state.isBusy,
                      state: state,
                    ),
                    const SizedBox(height: 24),
                    InfoCard(state: state),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleWeightChange(double? previous, double? next) {
    if (next == null) return;
    final begin = previous ?? _displayWeight;
    if ((begin - next).abs() < 0.0005) {
      setState(() => _displayWeight = next);
      return;
    }

    _weightAnimation = Tween<double>(begin: begin, end: next).animate(
      CurvedAnimation(parent: _weightController, curve: Curves.easeOutCubic),
    );
    _weightController.forward(from: 0);
  }

  void _resetAnimation() {
    _weightController.stop();
    setState(() => _displayWeight = 0);
  }

  String _formatWeight(double value) {
    final adjusted = value.abs() < 0.0005 ? 0.0 : value;
    return adjusted.toStringAsFixed(3);
  }
}

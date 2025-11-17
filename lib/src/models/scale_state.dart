enum ScaleStatus { searching, waitingUsb, connected, disconnected, error }

class ScaleState {
  final ScaleStatus status;
  final String statusText;
  final double? targetWeight;
  final bool isBusy;

  const ScaleState({
    required this.status,
    required this.statusText,
    this.targetWeight,
    this.isBusy = false,
  });

  factory ScaleState.initial() => const ScaleState(
    status: ScaleStatus.searching,
    statusText: 'กำลังค้นหาเครื่องชั่ง...',
    isBusy: true,
  );

  ScaleState copyWith({
    ScaleStatus? status,
    String? statusText,
    double? targetWeight,
    bool? isBusy,
  }) {
    return ScaleState(
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      targetWeight: targetWeight ?? this.targetWeight,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

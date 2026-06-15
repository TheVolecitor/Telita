class RefreshRateInfo {
  /// A list of refresh rates supported by the display.
  final List<double> supportedRates;

  /// The currently active refresh rate of the display.
  final double activeRate;

  RefreshRateInfo({required this.supportedRates, required this.activeRate});

  /// Creates a [RefreshRateInfo] object from a map.
  factory RefreshRateInfo.fromMap(Map<String, dynamic> map) {
    final supported =
        (map['supportedRates'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final active = (map['activeRate'] as num?)?.toDouble() ?? 0.0;
    return RefreshRateInfo(supportedRates: supported, activeRate: active);
  }
}

class MediaSegment {
  final String type;
  final int? startSec;
  final int endSec;

  MediaSegment({
    required this.type,
    this.startSec,
    required this.endSec,
  });

  factory MediaSegment.fromJson(Map<String, dynamic> json, String type) {
    // For IntroDB (start_sec, end_sec) or TheIntroDB (start_ms, end_ms)
    final num? s = json['start_sec'] ?? (json['start_ms'] != null ? json['start_ms'] / 1000 : null);
    final num? e = json['end_sec'] ?? (json['end_ms'] != null ? json['end_ms'] / 1000 : null);
    
    return MediaSegment(
      type: type,
      startSec: s?.round(),
      endSec: e?.round() ?? 0,
    );
  }
}

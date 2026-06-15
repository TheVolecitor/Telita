/// Represents the current playback state of the media.
///
/// This class is an internal data model for the UI that contains information
/// about the playback progress, received directly from the native Media3 player.
/// It includes the current position, duration, and buffered position.
///
/// Since this data reflects the player's state in real-time, it can be
/// used to implement external control (e.g., via IP) or other integrations,
/// allowing remote systems to track playback progress.
class PlaybackState {
  PlaybackState({
    this.position = 0,
    this.bufferedPosition = 0,
    this.duration = 0,
  });

  /// The current playback position in seconds.
  final int position;

  /// The total duration of the media in seconds.
  final int duration;

  /// The position to which the media has been loaded (buffered), in seconds.
  final int bufferedPosition;

  PlaybackState copyWith({
    int? position,
    int? duration,
    int? bufferedPosition,
  }) => PlaybackState(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    bufferedPosition: bufferedPosition ?? this.bufferedPosition,
  );

  @override
  String toString() {
    return '''PlaybackState{
      position: $position, 
      duration: $duration, 
      bufferedPosition: $bufferedPosition
    }''';
  }

  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'duration': duration,
      'bufferedPosition': bufferedPosition,
    };
  }

  factory PlaybackState.fromMap(Map<String, dynamic> map) {
    return PlaybackState(
      position: map['position'] as int,
      duration: map['duration'] as int,
      bufferedPosition: map['bufferedPosition'] as int,
    );
  }
}

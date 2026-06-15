/// This file defines the [PreviewPlayerEvent] class, which is a generic wrapper
/// for various events originating from the native Media3 preview player.
/// These events are used to communicate changes in player state, errors, and
/// other significant occurrences back to the Flutter UI.
library;

/// Represents a generic event originating from the native preview player.
///
/// This class encapsulates various events such as errors, playback state changes,
/// and the rendering of the first video frame. It provides a common structure
/// for all events received from the native platform.
class PreviewPlayerEvent {
  /// The ID of the texture associated with the player that emitted the event.
  final int textureId;

  /// The type of the event, typically a string identifier (e.g., 'onError', 'onPlaybackStarted', 'onIsPlaying').
  final String type;

  /// Optional additional data related to the event.
  /// The content of this map depends on the [type] of the event.
  final Map<dynamic, dynamic>? data;

  /// Creates a [PreviewPlayerEvent] instance.
  ///
  /// - [textureId]: The ID of the Flutter texture associated with the event.
  /// - [type]: A string identifier for the event type.
  /// - [data]: Optional payload for the event.
  PreviewPlayerEvent({required this.textureId, required this.type, this.data});

  /// Returns `true` if this event indicates an error condition.
  bool get isError => type == 'onError';

  /// Returns `true` if this event indicates that the first video frame has been rendered.
  bool get isPlaybackStarted => type == 'onPlaybackStarted';

  /// Returns `true` if this event indicates a change in the player's `isPlaying` state.
  bool get isPlayingChanged => type == 'onIsPlaying';

  @override
  String toString() {
    return 'PreviewPlayerEvent(textureId: $textureId, type: $type, data: $data)';
  }
}

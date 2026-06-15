/// This file defines the `Media3PreviewController` which acts as a Dart interface
/// to a native Media3 (ExoPlayer) instance. It manages the lifecycle, playback,
/// and events of a video rendered to a Flutter [Texture].
library;

import 'dart:async';

import 'preview_platform_channel.dart';
import 'preview_player_error.dart';

/// A controller for a native Media3 preview player instance.
///
/// This class provides a Dart interface to control a native ExoPlayer instance
/// that renders video to a Flutter [Texture]. It allows loading media, controlling
/// playback, seeking, setting volume, and listening to playback events and errors.
///
/// Typical usage:
/// ```dart
/// final controller = await Media3PreviewController.create();
/// await controller.loadUrl('https://example.com/video.mp4');
/// // ... use the controller ...
/// await controller.dispose();
/// ```
class Media3PreviewController {
  /// The ID of the Flutter [Texture] that displays the video from this player.
  ///
  /// This ID is used by the [Texture] widget to identify which native
  /// surface to render.
  final int textureId;

  late final Stream<PreviewPlayerError> _errors;

  /// A stream of [PreviewPlayerError]s that occur during playback.
  ///
  /// Listen to this stream to handle errors and update the UI accordingly.
  /// Errors might occur due to network issues, unsupported formats, etc.
  Stream<PreviewPlayerError> get errors => _errors;

  late final Stream<void> _playbackStarted;

  /// A stream that emits an event when the first video frame has been rendered.
  ///
  /// This can be used to hide a loading indicator or placeholder once the
  /// video content becomes visible. It's a key event for providing a smooth UX.
  Stream<void> get playbackStarted => _playbackStarted;

  /// A flag indicating if the native player resources have been released.
  bool _released = false;

  /// Internal constructor for [Media3PreviewController].
  ///
  /// Use the static [create] method to obtain an instance.
  /// Initializes the platform channel and sets up error and playback started streams.
  Media3PreviewController._(this.textureId) {
    final platform = PreviewPlatformChannel.instance;
    platform.init();

    _errors = platform.events
        .where((e) => e.textureId == textureId && e.isError)
        .map(
          (e) => PreviewPlayerError(
            textureId: e.textureId,
            errorCode: e.data?['errorCode'] as int? ?? 0,
            errorMessage: e.data?['errorMessage'] as String?,
          ),
        );

    _playbackStarted = platform.events
        .where((e) => e.textureId == textureId && e.isPlaybackStarted)
        .map((e) {});
  }

  /// Creates and initializes a new Media3 preview player on the native side.
  ///
  /// This method communicates with the native platform to allocate resources
  /// and create a new ExoPlayer instance linked to a Flutter [Texture].
  ///
  /// Throws an [Exception] if the native player fails to be created.
  /// Returns a [Future] that completes with a [Media3PreviewController] instance
  /// once the native player is created and ready.
  static Future<Media3PreviewController> create() async {
    final id = await PreviewPlatformChannel.instance.invoke<int>('create');
    if (id == null) {
      throw Exception('Failed to create native preview player.');
    }
    return Media3PreviewController._(id);
  }

  /// Loads and prepares a media item for playback.
  ///
  /// This sends a command to the native player to prepare the specified [url]
  /// with various playback options.
  ///
  /// * [url]: The URL of the media to load.
  /// * [width]: Optional. The desired video width. The native player might adjust this.
  /// * [height]: Optional. The desired video height. The native player might adjust this.
  /// * [volume]: The playback volume, from 0.0 (silent) to 1.0 (full volume). Defaults to 0.0.
  /// * [autoPlay]: Whether to start playback automatically after preparation. Defaults to `true`.
  /// * [isRepeat]: Whether the media should loop continuously. Defaults to `true`.
  /// * [startTimeSeconds]: Optional. The start position for clipping the media, in seconds.
  /// * [endTimeSeconds]: Optional. The end position for clipping the media, in seconds.
  Future<void> loadUrl(
    String url, {
    int? width,
    int? height,
    double volume = 0.0,
    bool autoPlay = true,
    bool isRepeat = true,
    int? startTimeSeconds,
    int? endTimeSeconds,
  }) {
    return PreviewPlatformChannel.instance.invoke('prepare', {
      'textureId': textureId,
      'url': url,
      'width': width,
      'height': height,
      'volume': volume,
      'autoPlay': autoPlay,
      'isRepeat': isRepeat,
      'startTimeSeconds': startTimeSeconds,
      'endTimeSeconds': endTimeSeconds,
    });
  }

  /// Starts or resumes media playback.
  ///
  /// This method sends a command to the native player to begin or continue playback.
  Future<void> play() {
    return PreviewPlatformChannel.instance.invoke('play', {
      'textureId': textureId,
    });
  }

  /// Pauses media playback.
  ///
  /// This method sends a command to the native player to pause playback.
  Future<void> pause() {
    return PreviewPlatformChannel.instance.invoke('pause', {
      'textureId': textureId,
    });
  }

  /// Seeks to a specific [position] in the media.
  ///
  /// * [position]: The target playback position as a [Duration].
  Future<void> seekTo(Duration position) {
    return PreviewPlatformChannel.instance.invoke('seekTo', {
      'textureId': textureId,
      'positionMs': position.inMilliseconds,
    });
  }

  /// Sets the playback [volume] of the native player.
  ///
  /// * [volume]: The playback volume, ranging from 0.0 (silent) to 1.0 (full volume).
  Future<void> setVolume(double volume) {
    return PreviewPlatformChannel.instance.invoke('setVolume', {
      'textureId': textureId,
      'volume': volume,
    });
  }

  /// Sets whether the media should loop continuously.
  ///
  /// * [looping]: If `true`, the media will repeat indefinitely. If `false`, it will play once.
  Future<void> setLooping(bool looping) {
    return PreviewPlatformChannel.instance.invoke('setRepeatMode', {
      'textureId': textureId,
      'isRepeat': looping,
    });
  }

  /// Releases the native player resources associated with this controller.
  ///
  /// Once released, the controller instance is no longer valid and should not
  /// be used. This makes the native player available for reuse in the native pool.
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await PreviewPlatformChannel.instance.invoke('release', {
      'textureId': textureId,
    });
  }

  /// Disposes of the controller and releases its native resources.
  ///
  /// This method is an alias for [release] and should be called when the
  /// controller is no longer needed to free up native resources.
  Future<void> dispose() async {
    await release();
  }
}

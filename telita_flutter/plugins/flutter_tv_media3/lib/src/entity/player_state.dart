import '../../flutter_tv_media3.dart';

/// Represents the current volume state of the player.
///
/// This includes the current volume level, maximum volume, and mute status.
class VolumeState {
  /// The current volume level.
  final int current;

  /// The maximum possible volume level.
  final int max;

  /// A flag indicating whether the audio is muted.
  final bool isMute;

  /// The current volume level as a double, from 0.0 to 1.0.
  final double volume;

  /// Creates a [VolumeState] with the given volume parameters.
  VolumeState({
    this.current = 0,
    this.max = 0,
    this.isMute = false,
    this.volume = 0.0,
  });

  /// Creates a copy of this [VolumeState] with optional new values.
  VolumeState copyWith({int? current, int? max, bool? isMute, double? volume}) {
    return VolumeState(
      current: current ?? this.current,
      max: max ?? this.max,
      isMute: isMute ?? this.isMute,
      volume: volume ?? this.volume,
    );
  }

  @override
  String toString() {
    return 'VolumeState{current: $current, max: $max, isMute: $isMute, volume: $volume}';
  }

  /// Converts this [VolumeState] instance to a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {'current': current, 'max': max, 'isMute': isMute, 'volume': volume};
  }

  /// Creates a [VolumeState] instance from a map (e.g., from JSON).
  factory VolumeState.fromMap(Map<String, dynamic> map) {
    return VolumeState(
      current: map['current'] as int? ?? 0,
      max: map['max'] as int? ?? 0,
      isMute: map['isMute'] as bool? ?? false,
      volume: (map['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Represents the complete current state of the player.
///
/// This class is the main internal data model for the UI, aggregating all
/// state information received directly from the native Media3 player.
/// It includes playback state, playlist information, errors,
/// available tracks, and settings.
///
/// Since this data reflects the player's state in real-time, it can be
/// used to implement external control (e.g., via IP) or other integrations,
/// allowing remote systems to track the full state of the player.
class PlayerState {
  PlayerState({
    this.activityReady = false,
    this.stateValue = StateValue.initial,
    this.playlist = const [],
    this.playIndex = -1,
    this.lastError,
    this.errorCode,
    this.isLive = false,
    this.isSeekable = false,
    this.loadingStatus,
    this.loadingProgress,
    this.videoTracks = const [],
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.zoom = PlayerZoom.fit,
    this.speed = 1.0,
    this.repeatMode = PlayerRepeatMode.repeatModeOff,
    this.isShuffleModeEnabled = false,
    SubtitleStyle? subtitleStyle,
    ClockSettings? clockSettings,
    PlayerSettings? playerSettings,
    VolumeState? volumeState,
    this.activityDestroyed = false,
    this.customInfoText,
  }) : subtitleStyle = subtitleStyle ?? SubtitleStyle(),
       clockSettings = clockSettings ?? ClockSettings(),
       volumeState = volumeState ?? VolumeState(),
       playerSettings = playerSettings ?? PlayerSettings();

  /// A flag indicating whether the native player Activity is ready.
  final bool activityReady;

  /// The main playback state (playing, paused, buffering, etc.).
  final StateValue stateValue;

  /// The current playlist.
  final List<PlaylistMediaItem> playlist;

  /// The index of the currently playing item in the playlist.
  final int playIndex;

  /// The text of the last error, if one occurred.
  final String? lastError;

  /// The code of the last error.
  final String? errorCode;

  /// A flag indicating whether the current stream is live.
  final bool isLive;

  /// A flag indicating whether seeking is possible in the current media.
  final bool isSeekable;

  /// The status of loading media information (e.g., getting a direct link).
  final String? loadingStatus;

  /// The progress of loading media information (from 0.0 to 1.0).
  final double? loadingProgress;

  /// The list of available video tracks.
  final List<VideoTrack> videoTracks;

  /// The list of available audio tracks.
  final List<AudioTrack> audioTracks;

  /// The list of available subtitle tracks.
  final List<SubtitleTrack> subtitleTracks;

  /// The current video zoom mode.
  final PlayerZoom zoom;

  /// The current playback speed.
  final double speed;

  /// The current repeat mode (off, one, all).
  final PlayerRepeatMode repeatMode;

  /// A flag indicating whether shuffle mode is enabled.
  final bool isShuffleModeEnabled;

  /// The current subtitle style settings.
  final SubtitleStyle subtitleStyle;

  /// The current clock settings.
  final ClockSettings clockSettings;

  /// The current player settings (quality, languages).
  final PlayerSettings playerSettings;

  /// A custom string to be displayed in the info panel.
  final String? customInfoText;

  final bool activityDestroyed;

  final VolumeState volumeState;

  PlayerState copyWith({
    bool? activityReady,
    StateValue? stateValue,
    List<PlaylistMediaItem>? playlist,
    int? playIndex,
    String? lastError,
    String? errorCode,
    bool? isLive,
    bool? isSeekable,
    String? loadingStatus,
    double? loadingProgress,
    final List<VideoTrack>? videoTracks,
    final List<AudioTrack>? audioTracks,
    final List<SubtitleTrack>? subtitleTracks,
    PlayerZoom? zoom,
    double? speed,
    PlayerRepeatMode? repeatMode,
    bool? isShuffleModeEnabled,
    SubtitleStyle? subtitleStyle,
    ClockSettings? clockSettings,
    PlayerSettings? playerSettings,
    VolumeState? volumeState,
    bool? resetError,
    String? customInfoText,
    bool? activityDestroyed,
  }) {
    return PlayerState(
      activityReady: activityReady ?? this.activityReady,
      stateValue: stateValue ?? this.stateValue,
      playlist: playlist ?? this.playlist,
      playIndex: playIndex ?? this.playIndex,
      lastError: resetError != null ? null : lastError ?? this.lastError,
      errorCode: resetError != null ? null : errorCode ?? this.errorCode,
      isLive: isLive ?? this.isLive,
      isSeekable: isSeekable ?? this.isSeekable,
      loadingStatus: loadingStatus ?? this.loadingStatus,
      loadingProgress: loadingProgress ?? this.loadingProgress,
      videoTracks: videoTracks ?? this.videoTracks,
      audioTracks: audioTracks ?? this.audioTracks,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      zoom: zoom ?? this.zoom,
      speed: speed ?? this.speed,
      repeatMode: repeatMode ?? this.repeatMode,
      isShuffleModeEnabled: isShuffleModeEnabled ?? this.isShuffleModeEnabled,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      clockSettings: clockSettings ?? this.clockSettings,
      playerSettings: playerSettings ?? this.playerSettings,
      volumeState: volumeState ?? this.volumeState,
      customInfoText: customInfoText ?? this.customInfoText,
      activityDestroyed: activityDestroyed ?? this.activityDestroyed,
    );
  }

  @override
  String toString() {
    return '''PlayerState{
      activityReady: $activityReady, 
      stateValue: $stateValue, 
      playlist: $playlist, 
      playIndex: $playIndex, 
      lastError: $lastError, 
      errorCode: $errorCode, 
      isLive: $isLive, 
      isSeekable: $isSeekable, 
      loadingStatus: $loadingStatus, 
      loadingProgress: $loadingProgress, 
      videoTracks: $videoTracks, 
      audioTracks: $audioTracks, 
      subtitleTracks: $subtitleTracks, 
      zoom: $zoom, 
      speed: $speed, 
      repeatMode: $repeatMode, 
      isShuffleModeEnabled: $isShuffleModeEnabled, 
      subtitleStyle: $subtitleStyle, 
      clockSettings: $clockSettings, 
      playerSettings: $playerSettings, 
      volumeState: $volumeState,
      customInfoText: $customInfoText, 
      activityDestroyed: $activityDestroyed
    }''';
  }

  Map<String, dynamic> toMap() {
    return {
      'activityReady': activityReady,
      'stateValue': stateValue.index,
      'playlist': playlist.map((item) => item.toMap()).toList(),
      'playIndex': playIndex,
      'lastError': lastError,
      'errorCode': errorCode,
      'isLive': isLive,
      'isSeekable': isSeekable,
      'loadingStatus': loadingStatus,
      'loadingProgress': loadingProgress,
      'videoTracks': videoTracks.map((track) => track.toMap()).toList(),
      'audioTracks': audioTracks.map((track) => track.toMap()).toList(),
      'subtitleTracks': subtitleTracks.map((track) => track.toMap()).toList(),
      'zoom': zoom.index,
      'speed': speed,
      'repeatMode': repeatMode.index,
      'isShuffleModeEnabled': isShuffleModeEnabled,
      'subtitleStyle': subtitleStyle.toMap(),
      'clockSettings': clockSettings.toMap(),
      'playerSettings': playerSettings.toMap(),
      'volumeState': volumeState.toMap(),
      'customInfoText': customInfoText,
      'activityDestroyed': activityDestroyed,
    };
  }

  factory PlayerState.fromMap(Map<String, dynamic> map) {
    return PlayerState(
      activityReady: map['activityReady'] as bool? ?? false,
      stateValue: StateValue.values[map['stateValue'] as int? ?? 0],
      playlist:
          (map['playlist'] as List<dynamic>?)
              ?.map(
                (item) =>
                    PlaylistMediaItem.fromMap(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      playIndex: map['playIndex'] as int? ?? -1,
      lastError: map['lastError'] as String?,
      errorCode: map['errorCode'] as String?,
      isLive: map['isLive'] as bool? ?? false,
      isSeekable: map['isSeekable'] as bool? ?? false,
      loadingStatus: map['loadingStatus'] as String?,
      loadingProgress: map['loadingProgress'] as double?,
      videoTracks:
          (map['videoTracks'] as List<dynamic>?)
              ?.map(
                (track) => VideoTrack.fromMap(track as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      audioTracks:
          (map['audioTracks'] as List<dynamic>?)
              ?.map(
                (track) => AudioTrack.fromMap(track as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      subtitleTracks:
          (map['subtitleTracks'] as List<dynamic>?)
              ?.map(
                (track) => SubtitleTrack.fromMap(track as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      zoom: PlayerZoom.values[map['zoom'] as int? ?? 0],
      speed: map['speed'] as double? ?? 1.0,
      repeatMode: PlayerRepeatMode.values[map['repeatMode'] as int? ?? 0],
      isShuffleModeEnabled: map['isShuffleModeEnabled'] as bool? ?? false,
      subtitleStyle:
          map['subtitleStyle'] != null
              ? SubtitleStyle.fromMap(
                map['subtitleStyle'] as Map<String, dynamic>,
              )
              : null,
      clockSettings:
          map['clockSettings'] != null
              ? ClockSettings.fromMap(
                map['clockSettings'] as Map<String, dynamic>,
              )
              : null,
      playerSettings:
          map['playerSettings'] != null
              ? PlayerSettings.fromMap(
                map['playerSettings'] as Map<String, dynamic>,
              )
              : null,
      volumeState:
          map['volumeState'] != null
              ? VolumeState.fromMap(map['volumeState'] as Map<String, dynamic>)
              : null,
      customInfoText: map['customInfoText'] as String?,
      activityDestroyed: map['activityDestroyed'] as bool? ?? false,
    );
  }
}

/// Defines the main states of the player lifecycle.
enum StateValue {
  initial,
  idle,
  buffering,
  playing,
  paused,
  ended,
  error,
  unknown;

  static StateValue fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'idle':
        return StateValue.idle;
      case 'buffering':
        return StateValue.buffering;
      case 'playing':
        return StateValue.playing;
      case 'paused':
        return StateValue.paused;
      case 'ended':
        return StateValue.ended;
      case 'error':
        return StateValue.error;
      default:
        return StateValue.unknown;
    }
  }

  String toJson() => name;
}

/// Defines the video scaling modes.
enum PlayerZoom {
  /// Fit the video to the screen while maintaining aspect ratio.
  fit('FIT'),

  /// Stretch the video to the full screen without maintaining aspect ratio.
  fill('FILL'),

  /// Fill the screen while maintaining aspect ratio (cropping may occur).
  zoom('ZOOM'),

  /// Fix the width.
  fixedWidth('FIXED_WIDTH'),

  /// Fix the height.
  fixedHeight('FIXED_HEIGHT'),

  /// Custom scaling.
  scale('SCALE');

  final String nativeValue;
  const PlayerZoom(this.nativeValue);

  static PlayerZoom? fromString(String? name) {
    if (name == null) return null;
    for (PlayerZoom enumVariant in PlayerZoom.values) {
      if (enumVariant.nativeValue == name) return enumVariant;
    }
    return null;
  }
}

/// Defines the playlist repeat modes.
enum PlayerRepeatMode {
  /// Do not repeat.
  repeatModeOff('REPEAT_MODE_OFF'),

  /// Repeat the current track.
  repeatModeOne('REPEAT_MODE_ONE'),

  /// Repeat the entire playlist.
  repeatModeAll('REPEAT_MODE_ALL');

  final String nativeValue;
  const PlayerRepeatMode(this.nativeValue);

  static PlayerRepeatMode? fromString(String? name) {
    if (name == null) return null;
    for (PlayerRepeatMode enumVariant in PlayerRepeatMode.values) {
      if (enumVariant.nativeValue == name) return enumVariant;
    }
    return null;
  }

  static PlayerRepeatMode nextValue(int index) {
    index = index + 1 == PlayerRepeatMode.values.length ? 0 : index + 1;
    return PlayerRepeatMode.values[index];
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';

import '../../entity/find_subtitles_state.dart';
import '../../entity/refresh_rate_info.dart';

/// Manages the state and interaction of the player UI overlay.
///
/// This controller is a singleton that operates **within a separate Flutter Engine**,
/// which is exclusively responsible for the player's user interface (the overlay).
///
/// **IMPORTANT:** It is **not directly accessible** from the main Flutter application's
/// code. All interaction happens indirectly:
/// 1.  **Receiving State:** The controller receives state updates (`PlayerState`,
///     `PlaybackState`, etc.) from the native player via a `MethodChannel`.
/// 2.  **Sending Commands:** It sends user commands (e.g., pause, seek,
///     track selection) back to the native layer through the same channel.
///
/// In essence, this is a bridge between the UI overlay widgets and the native player,
/// completely encapsulating the UI logic.
class Media3UiController {
  void Function()? onBackPressed;

  late PlaylistMediaItem playItem;

  PlayerState _playerState = PlayerState();
  PlayerState get playerState => _playerState;

  PlaybackState _playbackState = PlaybackState();
  PlaybackState get playbackState => _playbackState;

  MediaMetadata _currentMetadata = MediaMetadata();
  MediaMetadata get currentMetadata => _currentMetadata;

  static const MethodChannel _activityChannel = MethodChannel(
    'ui_player_plugin_activity',
  );

  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();

  /// A stream that broadcasts the full state of the player ([PlayerState]).
  /// UI widgets (like `OverlayUiBloc`) subscribe to this stream to react
  /// to changes (track changes, errors, track updates).
  Stream<PlayerState> get playerStateStream => _stateController.stream;

  final StreamController<PlaybackState> _playbackStateController =
      StreamController<PlaybackState>.broadcast();

  /// A stream that broadcasts the playback progress state ([PlaybackState]).
  /// Used to update progress sliders, timers, etc.
  Stream<PlaybackState> get playbackStateStream =>
      _playbackStateController.stream;

  final StreamController<MediaMetadata> _mediaMetadataController =
      StreamController<MediaMetadata>.broadcast();

  /// A stream that broadcasts the metadata of the current media ([MediaMetadata]).
  /// Used to display the title, artist, etc.
  Stream<MediaMetadata> get mediaMetadataStream =>
      _mediaMetadataController.stream;

  /// Notifier that holds the entire state for the "Find Subtitles" UI.
  ///
  /// Widgets will listen to this notifier to rebuild reactively whenever the
  /// state changes. It is initialized with a default, invisible state.
  final ValueNotifier<FindSubtitlesState> findSubtitlesStateNotifier =
      ValueNotifier(const FindSubtitlesState());

  /// Constructor that initializes states and the native call handler.
  Media3UiController() {
    _initStates();
    _activityChannel.setMethodCallHandler(_handleNativeCallbacks);
  }

  /// Notifies the native layer that the UI overlay entry point has been called.
  void overlayEntryPointCalled() {
    _invokeMethodGuarded(_activityChannel, 'onOverlayEntryPointCalled');
  }

  void initForWindows(List<PlaylistMediaItem> playlist, int initialIndex) {
    if (playlist.isNotEmpty && initialIndex >= 0 && initialIndex < playlist.length) {
      playItem = playlist[initialIndex];
      _playerState = _playerState.copyWith(
        playlist: playlist,
        playIndex: initialIndex,
        stateValue: StateValue.playing,
      );
      _stateController.add(_playerState);
    }
  }

  void _initStates() {
    _stateController.add(_playerState);
    _playbackStateController.add(_playbackState);
    _mediaMetadataController.add(_currentMetadata);
  }

  /// Internal handler for incoming calls from the native side.
  ///
  /// Parses calls, updates the corresponding states (`_playerState`, `_playbackState`),
  /// and notifies listeners via streams.
  Future<dynamic> _handleNativeCallbacks(MethodCall call) async {
    PlayerState newState = _playerState;

    switch (call.method) {
      case 'onBack':
        if (onBackPressed != null) {
          onBackPressed!();
        }
        break;

      case 'onActivityReady':
        final playlistStr = call.arguments['playlist'] as String? ?? '{}';
        final playIndex = call.arguments['playlist_index'] as int? ?? 0;
        final Map<dynamic, dynamic>? subtitleStyleMap =
            call.arguments['subtitle_style'];
        final subtitleStyle =
            subtitleStyleMap != null
                ? SubtitleStyle.fromMap(subtitleStyleMap)
                : null;
        final playlistList = jsonDecode(playlistStr) as List<dynamic>;
        final clockSettingsStr = call.arguments['clock_settings'] as String?;
        final clockSettings =
            clockSettingsStr != null
                ? ClockSettings.fromMap(jsonDecode(clockSettingsStr))
                : null;
        final Map<dynamic, dynamic>? playerSettingsMap =
            call.arguments['player_settings'];
        PlayerSettings playerSettings =
            playerSettingsMap != null
                ? PlayerSettings.fromMap(playerSettingsMap)
                : PlayerSettings();
        if (playerSettings.deviceLocale != null) {
          OverlayLocalizations.updateLocale(playerSettings.deviceLocale!);
        }
        List<PlaylistMediaItem> currentPlaylist =
            playlistList.map((e) => PlaylistMediaItem.fromMap(e)).toList();
        if (currentPlaylist.length > playIndex) {
          playItem = currentPlaylist[playIndex];
        }
        Map<String, dynamic> localeStringsMap = jsonDecode(
          call.arguments['locale_strings'] as String? ?? '{}',
        );
        final Map<String, String> newStrings = localeStringsMap.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
        Map<String, dynamic> subtitleSearchMap = jsonDecode(
          call.arguments['subtitle_search'] as String? ?? '{}',
        );
        final FindSubtitlesState findSubtitlesState =
            FindSubtitlesState.fromMap(subtitleSearchMap);
        findSubtitlesStateNotifier.value = findSubtitlesState;

        final Map<dynamic, dynamic>? volumeStateMap =
            call.arguments['volume_state'];
        VolumeState? volumeState;
        if (volumeStateMap != null) {
          final current = volumeStateMap['current'] as int?;
          final max = volumeStateMap['max'] as int?;
          final isMute = volumeStateMap['isMute'] as bool?;
          if (current != null && max != null && isMute != null) {
            volumeState = VolumeState(
              current: current,
              max: max,
              isMute: isMute,
            );
          }
        }

        OverlayLocalizations.load(newStrings);
        newState = newState.copyWith(
          activityReady: true,
          playlist: currentPlaylist,
          playIndex: playIndex,
          subtitleStyle: subtitleStyle,
          clockSettings: clockSettings,
          playerSettings: playerSettings,
          volumeState: volumeState,
        );
        break;

      case 'onPlaylistUpdated':
      case 'onItemRemoved':
        final playlistStr = call.arguments['playlist'] as String?;
        final playIndex = call.arguments['playlist_index'] as int?;
        if (playlistStr != null) {
          final playlistList = jsonDecode(playlistStr) as List<dynamic>;
          final currentPlaylist =
              playlistList.map((e) => PlaylistMediaItem.fromMap(e)).toList();
          newState = newState.copyWith(
            playlist: currentPlaylist,
            playIndex: playIndex ?? newState.playIndex,
          );
          if (newState.playlist.length > newState.playIndex) {
            playItem = newState.playlist[newState.playIndex];
          }
        }
        break;

      case 'onStateChanged':
        final stateValue = call.arguments['state'] as String?;
        final isLive = call.arguments['isLive'] as bool? ?? false;
        final isSeekable = call.arguments['isSeekable'] as bool? ?? false;
        final playIndex = call.arguments['playlist_index'] as int? ?? 0;
        final speed = (call.arguments['speed'] as num?)?.toDouble();
        final repeatMode = call.arguments['repeatMode'] as String?;
        final shuffleEnabled =
            call.arguments['shuffleEnabled'] as bool? ?? false;
        if (newState.playlist.length > playIndex) {
          playItem = newState.playlist[playIndex];
        }
        newState = newState.copyWith(
          stateValue: StateValue.fromString(stateValue),
          isLive: isLive,
          isSeekable: isSeekable,
          playIndex: playIndex,
          speed: speed,
          repeatMode: PlayerRepeatMode.fromString(repeatMode),
          isShuffleModeEnabled: shuffleEnabled,
        );
        break;

      case 'onPositionChanged':
        final data = Map<String, dynamic>.from(call.arguments);
        final newPositionMs = (data['position'] as num?)?.toInt();
        final newBufferedMs = (data['bufferedPosition'] as num?)?.toInt();
        final durationMs = (data['duration'] as num?)?.toInt();

        final newPlaybackState = _playbackState.copyWith(
          position:
              newPositionMs != null ? (newPositionMs / 1000).toInt() : null,
          bufferedPosition:
              newBufferedMs != null ? (newBufferedMs / 1000).toInt() : null,
          duration: durationMs != null ? (durationMs / 1000).toInt() : null,
        );
        _updatePlaybackState(newPlaybackState);
        return;

      case 'loadMediaInfo':
        final playIndex = call.arguments['playlist_index'] ?? 0;
        if (newState.playlist.length > playIndex) {
          playItem = newState.playlist[playIndex];
        }
        newState = PlayerState().copyWith(
          playIndex: playIndex,
          playlist: newState.playlist,
          clockSettings: newState.clockSettings,
          playerSettings: newState.playerSettings,
        );
        _updatePlaybackState(PlaybackState());
        break;

      case "loadMediaInfoState":
        final state = call.arguments['state'] as String?;
        final progress = call.arguments['progress'] as double?;
        if (state != null) {
          newState = newState.copyWith(
            loadingStatus: state,
            loadingProgress: progress,
          );
        }
        break;

      case 'loadedMediaInfo':
        final playIndex = call.arguments['playlist_index'] ?? 0;
        final loadingStatus = "Buffering...";
        if (newState.playlist.length > playIndex) {
          playItem = newState.playlist[playIndex];
        }
        newState = newState.copyWith(
          playIndex: playIndex,
          loadingStatus: loadingStatus,
          loadingProgress: null,
        );
        break;

      case 'onWatchTimeMarked':
        final index = call.arguments['playlist_index'] as int?;
        final int durationMs = call.arguments['duration_ms'] as int? ?? 0;
        final int positionMs = call.arguments['position_ms'] as int? ?? 0;
        List<PlaylistMediaItem> currentPlaylist = List.from(
          _playerState.playlist,
        );
        if (index != null && index < currentPlaylist.length) {
          final currentItem = currentPlaylist[index];
          if (currentItem.updateWatchTime == true) {
            final item = currentPlaylist[index].copyWith(
              startPosition: (positionMs / 1000).round(),
              duration: (durationMs / 1000).round(),
            );
            currentPlaylist[index] = item;
            newState = newState.copyWith(playlist: currentPlaylist);
          }
        }
        _updateState(newState);
        return;
      case 'onMetadataChanged':
        final rawData = call.arguments as Map<Object?, Object?>?;
        _currentMetadata = MediaMetadata.fromMap(rawData);
        _mediaMetadataController.add(_currentMetadata);
        break;

      case 'onStreamingMetadataUpdated':
        final rawStreamingData = call.arguments as Map<Object?, Object?>?;
        final newStreamingMetadata = StreamingMetadata.fromMap(
          rawStreamingData,
        );
        _currentMetadata = _currentMetadata.copyWith(
          streamingMetadata: newStreamingMetadata,
        );
        _mediaMetadataController.add(_currentMetadata);
        break;

      case 'onError':
        newState = newState.copyWith(
          lastError:
              call.arguments['message'] as String? ??
              'An unknown playback error occurred.',
          errorCode: call.arguments['code'] as String?,
        );
        break;
      case "setCurrentResizeMode":
        final String? zoomValue = call.arguments['zoom'] as String?;
        if (zoomValue == null) {
          newState = newState.copyWith(
            lastError: 'zoomValue is null in response',
            errorCode: 'ZOOM_RESPONSE_ERROR',
          );
        } else {
          newState = newState.copyWith(zoom: PlayerZoom.fromString(zoomValue));
        }
        break;
      case "setCurrentSpeed":
        final speedValue = call.arguments['speed'] as double?;
        if (speedValue == null) {
          newState = newState.copyWith(
            lastError: 'Null speed value in response',
            errorCode: 'SPEED_RESPONSE_ERROR',
          );
        } else {
          newState = newState.copyWith(speed: speedValue);
        }
        break;
      case "setRepeatMode":
        final repeat = call.arguments['mode'] as String?;
        if (repeat == null) {
          newState = newState.copyWith(
            lastError: 'Null speed value in response',
            errorCode: 'SET_REPEAT_MODE',
          );
        } else {
          newState = newState.copyWith(
            repeatMode: PlayerRepeatMode.fromString(repeat),
          );
        }
        break;
      case "setShuffleMode":
        final shuffleEnabled = call.arguments['shuffleEnabled'] as bool?;
        if (shuffleEnabled == null) {
          newState = newState.copyWith(
            lastError: 'Null speed value in response',
            errorCode: 'SET_SHUFFLE_MODE',
          );
        } else {
          newState = newState.copyWith(isShuffleModeEnabled: shuffleEnabled);
        }
        break;
      case "updateSubtitleStyle":
        final result = call.arguments;
        if (result is! Map) {
          newState = newState.copyWith(
            lastError: 'Unknown or null result type',
            errorCode: 'UPDATE_SUBTITLE_STYLE_ERROR',
          );
        } else {
          final Map map = result;
          final subtitleStyle = SubtitleStyle.fromMap(map);
          newState = newState.copyWith(subtitleStyle: subtitleStyle);
        }
        break;
      case 'setCurrentTracks':
        final List<dynamic> rawTracks = call.arguments;
        try {
          final List<MediaTrack> tracksList =
              rawTracks
                  .cast<Map<dynamic, dynamic>>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .map(MediaTrack.fromMap)
                  .toList();
          List<VideoTrack> videoTracks =
              tracksList.whereType<VideoTrack>().toList();
          List<AudioTrack> audioTracks =
              tracksList.whereType<AudioTrack>().toList();
          List<SubtitleTrack> subtitleTracks =
              tracksList.whereType<SubtitleTrack>().toList();
          newState = newState.copyWith(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            subtitleTracks: subtitleTracks,
          );
        } catch (e) {
          newState = newState.copyWith(
            lastError: e.toString(),
            errorCode: 'SET_CURRENT_TRACKS_ERROR',
          );
        }
        break;
      case 'onCustomInfoUpdate':
        final text = call.arguments['text'] as String?;
        newState = newState.copyWith(customInfoText: text);
        break;
      case 'onSubtitleSearchStateChanged':
        final Map<String, dynamic> subtitleSearchMap =
            Map<String, dynamic>.from(call.arguments);
        final FindSubtitlesState findSubtitlesState =
            FindSubtitlesState.fromMap(subtitleSearchMap);
        findSubtitlesStateNotifier.value = findSubtitlesState;
        break;
      case 'onVolumeChanged':
        final current = call.arguments['current'] as int?;
        final max = call.arguments['max'] as int?;
        final isMute = call.arguments['isMute'] as bool?;
        final volume = (call.arguments['volume'] as num?)?.toDouble();
        if (current != null &&
            max != null &&
            isMute != null &&
            volume != null) {
          newState = newState.copyWith(
            volumeState: VolumeState(
              current: current,
              max: max,
              isMute: isMute,
              volume: volume,
            ),
          );
        }
        break;
      default:
        newState = newState.copyWith(
          lastError: "Unhandled native callback method: ${call.method}",
          errorCode: 'OverlayPlayerController',
        );
        return;
    }
    _updateState(newState);
  }

  void _updatePlaybackState(PlaybackState newPlaybackState) {
    _playbackState = newPlaybackState;
    _playbackStateController.add(newPlaybackState);
  }

  /// Sends a "find subtitles" command to the native player, which will be
  /// forwarded to the main application.
  Future<void> findSubtitles() async {
    // Immediately update the UI to show the loading state.
    findSubtitlesStateNotifier.value = findSubtitlesStateNotifier.value
        .copyWith(status: SubtitleSearchStatus.loading, resetError: true);
    // Send the request to the native side.
    await _invokeMethodGuarded<void>(_activityChannel, 'findSubtitles', {
      'mediaId': playItem.id,
    });
  }

  /// Sends a "play/pause" command to the native player.
  Future<void> playPause() async =>
      await _invokeMethodGuarded<void>(_activityChannel, 'playPause');

  /// Sends a "play" command to the native player.
  Future<void> play() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'play');
  }

  /// Sends a "pause" command to the native player.
  Future<void> pause() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'pause');
  }

  /// Sends a "seek" command to the native player.
  Future<void> seekTo({required int positionSeconds}) async {
    await _invokeMethodGuarded<void>(_activityChannel, 'seekTo', {
      "position": positionSeconds * 1000,
    });
  }

  /// Sends a command to set the playback speed.
  Future<void> setSpeed({required double speed}) async {
    try {
      final result = await _invokeMethodGuarded<Map<Object?, Object?>>(
        _activityChannel,
        'setSpeed',
        {'speed': speed},
      );

      final speedValue = result?['speed'] as double?;
      if (speedValue == null) {
        _updateState(
          _playerState.copyWith(
            lastError: 'Null speed value in response',
            errorCode: 'SPEED_RESPONSE_ERROR',
          ),
        );
        return;
      }

      _updateState(_playerState.copyWith(speed: speedValue));
    } on PlatformException catch (e) {
      _updateState(
        _playerState.copyWith(
          lastError: e.message ?? 'Unknown platform error',
          errorCode: e.code,
        ),
      );
    } catch (e) {
      _updateState(
        _playerState.copyWith(
          lastError: 'Failed to set speed: $e',
          errorCode: 'SPEED_CHANNEL_ERROR',
        ),
      );
    }
  }

  /// Sends a command to set the repeat mode.
  Future<void> setRepeatMode({required PlayerRepeatMode repeatMode}) async {
    try {
      final result = await _invokeMethodGuarded<Map<Object?, Object?>>(
        _activityChannel,
        'setRepeatMode',
        {'mode': repeatMode.nativeValue},
      );

      final repeat = result?['mode'] as String?;
      if (repeat == null) {
        _updateState(
          _playerState.copyWith(
            lastError: 'Null speed value in response',
            errorCode: 'SET_REPEAT_MODE',
          ),
        );
        return;
      }
      _updateState(
        _playerState.copyWith(repeatMode: PlayerRepeatMode.fromString(repeat)),
      );
    } on PlatformException catch (e) {
      _updateState(
        _playerState.copyWith(
          lastError: e.message ?? 'Unknown platform error',
          errorCode: e.code,
        ),
      );
    } catch (e) {
      _updateState(
        _playerState.copyWith(
          lastError: 'Failed to set speed: $e',
          errorCode: 'SET_REPEAT_MODE',
        ),
      );
    }
  }

  /// Sends a command to set the shuffle mode.
  Future<void> setShuffleMode(bool enabled) async {
    try {
      final result = await _invokeMethodGuarded<Map<Object?, Object?>>(
        _activityChannel,
        'setShuffleMode',
        {'enabled': enabled},
      );
      final shuffleEnabled = result?['shuffleEnabled'] as bool?;
      if (shuffleEnabled == null) {
        _updateState(
          _playerState.copyWith(
            lastError: 'Null speed value in response',
            errorCode: 'SET_SHUFFLE_MODE',
          ),
        );
        return;
      }
      _updateState(_playerState.copyWith(isShuffleModeEnabled: shuffleEnabled));
    } on PlatformException catch (e) {
      _updateState(
        _playerState.copyWith(
          lastError: e.message ?? 'Unknown platform error',
          errorCode: e.code,
        ),
      );
    }
  }

  /// Sends a "stop" command to the native player.
  Future<void> stop() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'stop');
  }

  /// Sends a command to trigger the "load more" (pagination) logic on the main application.
  Future<void> onLoadMoreCalled() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'onLoadMore');
  }

  /// Sends a command to trigger the sleep timer logic on the native side.
  Future<void> sleepTimerExec() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'sleepTimerExec');
  }

  /// Sends a command to set the video zoom/resize mode.
  Future<void> setZoom({required PlayerZoom zoom}) async {
    if (playerState.zoom == PlayerZoom.scale) {
      await _invokeMethodGuarded<void>(_activityChannel, 'setScale');
    }
    await _executeZoomCommand('setResizeMode', {"mode": zoom.nativeValue});
  }

  /// Sends a command to set a custom video scale.
  Future<void> setScale({
    required double scaleX,
    required double scaleY,
  }) async {
    if (playerState.zoom != PlayerZoom.scale) {
      await _invokeMethodGuarded<void>(_activityChannel, 'setResizeMode', {
        "mode": 'FILL',
      });
    }
    await _executeZoomCommand('setScale', {"scaleX": scaleX, "scaleY": scaleY});
  }

  /// Sends a command to save the clock settings.
  Future<void> saveClockSettings({ClockSettings? clockSettings}) async {
    final clockSettingsMap = clockSettings?.toMap();
    final clockSettingsStr =
        clockSettingsMap != null ? jsonEncode(clockSettingsMap) : null;
    try {
      await _invokeMethodGuarded<Map<dynamic, dynamic>>(
        _activityChannel,
        'saveClockSettings',
        {"clock_settings": clockSettingsStr},
      );
      _updateState(_playerState.copyWith(clockSettings: clockSettings));
    } catch (e) {
      _updateState(
        _playerState.copyWith(
          lastError: e.toString(),
          errorCode: 'UPDATE_CLOCK_SETTINGS_ERROR',
        ),
      );
    }
  }

  /// Sends a command to apply a new subtitle style.
  Future<void> updateSubtitleStyle({SubtitleStyle? subtitleStyle}) async {
    // On Windows media_kit is used directly — no MethodChannel. Update state
    // immediately so the player screen's stream listener picks it up.
    if (Platform.isWindows) {
      _updateState(_playerState.copyWith(subtitleStyle: subtitleStyle));
      return;
    }
    final subtitleStyleMap = subtitleStyle?.toMap();
    try {
      final dynamic result = await _invokeMethodGuarded<Map<dynamic, dynamic>>(
        _activityChannel,
        'setSubtitleStyle',
        subtitleStyleMap,
      );

      if (result is! Map) {
        _playerState.copyWith(
          lastError: 'Unknown or null result type',
          errorCode: 'UPDATE_SUBTITLE_STYLE_ERROR',
        );
        return;
      }
      final Map map = result;
      final subtitleStyle = SubtitleStyle.fromMap(map);
      _updateState(_playerState.copyWith(subtitleStyle: subtitleStyle));
    } on PlatformException catch (e) {
      _updateState(
        _playerState.copyWith(lastError: e.message, errorCode: e.code),
      );
    } catch (e) {
      _updateState(
        _playerState.copyWith(
          lastError: e.toString(),
          errorCode: 'UPDATE_SUBTITLE_STYLE_ERROR',
        ),
      );
    }
  }


  /// Sends a command to save the player settings.
  Future<void> savePlayerSettings({PlayerSettings? playerSettings}) async {
    final playerSettingsMap = playerSettings?.toMap();
    try {
      await _invokeMethodGuarded<void>(
        _activityChannel,
        'savePlayerSettings',
        playerSettingsMap,
      );
      _updateState(_playerState.copyWith(playerSettings: playerSettings));
    } on PlatformException catch (e) {
      _updateState(
        _playerState.copyWith(lastError: e.message, errorCode: e.code),
      );
    } catch (e) {
      _updateState(
        _playerState.copyWith(
          lastError: e.toString(),
          errorCode: 'UPDATE_PLAYER_SETTINGS_ERROR',
        ),
      );
    }
  }

  Future<void> _executeZoomCommand(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      final dynamic result = await _invokeMethodGuarded<dynamic>(
        _activityChannel,
        method,
        args,
      );
      _updateState(_handleZoomResult(result));
    } on PlatformException catch (e) {
      _updateState(
        _playerState.copyWith(lastError: e.message, errorCode: e.code),
      );
    } catch (e) {
      _updateState(
        _playerState.copyWith(
          lastError: e.toString(),
          errorCode: 'ZOOM_CHANNEL_ERROR',
        ),
      );
    }
  }

  PlayerState _handleZoomResult(dynamic result) {
    if (result is! Map) {
      return _playerState.copyWith(
        lastError: 'Unknown or null result type',
        errorCode: 'ZOOM_RESPONSE_ERROR',
      );
    }

    final Map<Object?, Object?> resultMap = result;
    final String? zoomValue = resultMap['zoom'] as String?;

    if (zoomValue == null) {
      return _playerState.copyWith(
        lastError: 'zoomValue is null in response',
        errorCode: 'ZOOM_RESPONSE_ERROR',
      );
    }
    return _playerState.copyWith(zoom: PlayerZoom.fromString(zoomValue));
  }

  /// Sends a command to get the current tracks from the native player.
  Future<List<MediaTrack>> getCurrentTracks() async {
    final result = await _invokeMethodGuarded<dynamic>(
      _activityChannel,
      'getCurrentTracks',
    );
    final tracks = List<Map<String, dynamic>>.from(result);
    return tracks.map((track) => MediaTrack.fromMap(track)).toList();
  }

  /// Sends a command to select a specific audio track.
  Future<void> selectAudioTrack({AudioTrack? track}) async =>
      await _selectTrack(track);

  /// Sends a command to select a specific subtitle track.
  Future<void> selectSubtitleTrack({SubtitleTrack? track}) async =>
      await _selectTrack(track);

  /// Sends a command to select a specific video track.
  Future<void> selectVideoTrack({VideoTrack? track}) async {
    if (track?.isExternal == true) {
      final url = track?.url;
      if (url != null) {
        await _invokeMethodGuarded<void>(
          _activityChannel,
          'selectExternalVideoTrack',
          {'url': url},
        );
      } else {
        throw ArgumentError('External video track must have a valid URL.');
      }
      return;
    }
    await _selectTrack(track);
  }

  Future<void> _selectTrack(MediaTrack? track) async {
    final trackIndex = track?.index;
    final groupIndex = track?.groupIndex;
    final trackType = track?.trackType;
    if (trackIndex == null || groupIndex == null || trackType == null) {
      throw ArgumentError(
        'You must provide a track index or a track with index.',
      );
    }
    await _invokeMethodGuarded<void>(_activityChannel, 'selectTrack', {
      "trackType": trackType,
      'trackIndex': trackIndex,
      'groupIndex': groupIndex,
    });
  }

  /// Sends a command to get the latest metadata from the native player.
  Future<void> getMetaData() async {
    final result = await _invokeMethodGuarded<dynamic>(
      _activityChannel,
      'getMetadata',
    );
    final Map<Object?, Object?> resultMap = result;
    _currentMetadata = MediaMetadata.fromMap(resultMap);
    _mediaMetadataController.add(_currentMetadata);
  }

  /// Sends a command to reset the last error state.
  void resetError() => _updateState(_playerState.copyWith(resetError: true));

  /// Sends a command to play the next item in the playlist.
  Future<void> playNext() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'playNext');
  }

  /// Sends a command to play the previous item in the playlist.
  Future<void> playPrevious() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'playPrevious');
  }

  /// Sends a command to play the item at the specified index.
  Future<void> playSelectedIndex({required int index}) async {
    if (_playerState.playlist.length > index && index >= 0) {
      await _invokeMethodGuarded<void>(_activityChannel, 'playSelectedIndex', {
        "index": index,
      });
    } else {
      final newState = _playerState.copyWith(
        stateValue: StateValue.error,
        lastError: 'Invalid index: $index',
        errorCode: 'OverlayPlayerController',
      );
      _updateState(newState);
    }
  }

  /// Internal wrapper for invoking methods on the native side
  /// with safe error handling.
  Future<T?> _invokeMethodGuarded<T>(
    MethodChannel channel,
    String method, [
    dynamic arguments,
  ]) async {
    try {
      final T? result = await channel.invokeMethod<T>(method, arguments);
      return result;
    } on PlatformException catch (e) {
      final newState = _playerState.copyWith(
        lastError: e.message ?? 'An unknown playback error occurred.',
        errorCode: '$method: ${e.code}',
      );
      _updateState(newState);
    } catch (e) {
      final newState = _playerState.copyWith(
        lastError: e.toString(),
        errorCode: method,
      );
      _updateState(newState);
    }
    return null;
  }

  /// Requests a video thumbnail from the native side.
  ///
  /// [uri] The URI of the video.
  /// [timeInSeconds] The time in seconds from which to extract the frame.
  Future<Uint8List?> getVideoThumbnail(
    String uri, {
    double? timeInSeconds,
  }) async {
    final Map<String, dynamic> arguments = {'uri': uri};
    if (timeInSeconds != null && timeInSeconds >= 0) {
      arguments['timeInSeconds'] = timeInSeconds;
    }
    final Uint8List? result = await _invokeMethodGuarded(
      _activityChannel,
      'getThumbnail',
      arguments,
    );
    return result;
  }

  void _updateState(PlayerState newState) {
    if (_playerState != newState) {
      _playerState = newState;
      if (!_stateController.isClosed) {
        _stateController.add(_playerState);
      }
    }
  }

  /// Retrieves the supported and active refresh rates from the display.
  ///
  /// Returns a map containing a list of supported rates and the currently
  /// active rate.
  Future<RefreshRateInfo> getRefreshRateInfo() async {
    final result = await _invokeMethodGuarded<Map<dynamic, dynamic>>(
      _activityChannel,
      'getRefreshRateInfo',
    );
    final map =
        result?.map((key, value) => MapEntry(key.toString(), value)) ?? {};
    return RefreshRateInfo.fromMap(map);
  }

  /// Manually sets the display's refresh rate.
  ///
  /// This method will fail if Auto Frame Rate (AFR) is enabled.
  ///
  /// - [rate]: The desired refresh rate.
  Future<void> setManualFrameRate(double rate) async {
    await _invokeMethodGuarded<void>(_activityChannel, 'setManualFrameRate', {
      'rate': rate,
    });
  }

  /// Fetches the current volume state from the native player.
  Future<VolumeState> getVolume() async {
    final result = await _invokeMethodGuarded<Map<dynamic, dynamic>>(
      _activityChannel,
      'getVolume',
    );
    final current = result?['current'] as int?;
    final max = result?['max'] as int?;
    final isMute = result?['isMute'] as bool?;
    final volume = (result?['volume'] as num?)?.toDouble();
    if (current != null && max != null && isMute != null && volume != null) {
      final volumeState = VolumeState(
        current: current,
        max: max,
        isMute: isMute,
        volume: volume,
      );
      _updateState(_playerState.copyWith(volumeState: volumeState));
      return volumeState;
    }
    throw Exception('Failed to parse volume data from native.');
  }

  /// Sets the volume on the native player.
  /// [volume] The volume level to set, from 0.0 to 1.0.
  Future<void> setVolume({required double volume}) async {
    await _invokeMethodGuarded<void>(_activityChannel, 'setVolume', {
      'volume': volume.clamp(0.0, 1.0),
    });
  }

  /// Mutes or unmutes the audio on the native player.
  /// [mute] True to mute, false to unmute.
  Future<void> setMute({required bool mute}) async {
    await _invokeMethodGuarded<void>(_activityChannel, 'setMute', {
      'mute': mute,
    });
  }

  /// Toggles the mute state on the native player.
  Future<void> toggleMute() async {
    final result = await _invokeMethodGuarded<Map<dynamic, dynamic>>(
      _activityChannel,
      'toggleMute',
    );
    final isMute = result?['isMute'] as bool?;
    if (isMute != null) {
      _updateState(
        _playerState.copyWith(
          volumeState: _playerState.volumeState.copyWith(isMute: isMute),
        ),
      );
    }
  }
}

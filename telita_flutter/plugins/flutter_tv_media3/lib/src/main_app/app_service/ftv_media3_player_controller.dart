import 'dart:async';
import 'dart:io';

import 'dart:convert';
import '../../utils/platform_utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import 'package:flutter_acrylic/flutter_acrylic.dart';
import '../../../flutter_tv_media3.dart';
import '../../entity/find_subtitles_state.dart';
import '../../entity/refresh_rate_info.dart';

/// A callback to save the current subtitle style settings.
typedef SaveSubtitleStyle =
    Future<void> Function({required SubtitleStyle subtitleStyle});

/// A callback to save the current clock settings.
typedef SaveClockSettings =
    Future<void> Function({required ClockSettings clockSettings});

/// A callback to save the current player settings.
typedef SavePlayerSettings =
    Future<void> Function({required PlayerSettings playerSettings});

/// A callback triggered when a screenshot (frame extraction) is taken.
///
/// This callback is primarily used when a user triggers a screenshot from the
/// player's UI (e.g., via the info panel).
/// It provides the [bytes] of the captured frame (PNG format) and the [item]
/// from which the screenshot was taken.
typedef OnScreenshotTaken =
    Future<void> Function({
      required Uint8List bytes,
      required PlaylistMediaItem item,
    });

/// Defines the signature for the function that searches for external subtitles.
///
/// It receives the [id] of the current media item and should return a list
/// of found subtitles or null if the search fails.
typedef SearchExternalSubtitle =
    Future<List<MediaItemSubtitle>?> Function({required String id});
typedef LabelSearchExternalSubtitle = Future<String> Function();

/// Manages the communication and state for the Media3 player from the main app.
///
/// This class is a singleton that acts as a bridge between the main Flutter application
/// and the native Android Media3 player, which runs with its own UI in a separate Flutter Engine.
///
/// The primary responsibilities of this controller are:
/// - **Launching the player:** Initiating the player activity with a specific playlist and settings.
/// - **Saving settings:** Persisting user preferences like subtitle styles, player settings, and clock settings that are configured within the player UI.
/// - **Triggering watch time saves:** Invoking callbacks provided by individual media items to save their playback progress.
///
/// All the primary user interactions (like pressing play/pause on the remote) are handled by the UI
/// running in the separate Flutter Engine.
///
/// The playback control methods exposed by this controller (e.g., [playPause], [play], [pause], [seekTo])
/// are intended for **external control scenarios**, such as:
/// - Remote control from another part of the main application.
/// - IP-based control from other devices on the network.
/// - Programmatic control based on application logic outside the player UI.
///
/// It exposes streams for different parts of the player's state:
/// - [playerStateStream]: For the overall state of the player ([PlayerState]).
/// - [playbackStateStream]: For playback-specific state like position and duration ([PlaybackState]).
/// - [mediaMetadataStream]: For the metadata of the currently playing media ([MediaMetadata]).
class FtvMedia3PlayerController {
  /// The method channel used for communication from the native plugin to Flutter.
  static const MethodChannel _pluginChannel = MethodChannel(
    'app_player_plugin',
  );

  /// The method channel used for communication from Flutter to the native player Activity.
  static const MethodChannel _activityChannel = MethodChannel(
    'app_player_plugin_activity',
  );

  /// Listens to commands sent by the overlay UI on desktop (replaces the Android
  /// activity layer that normally handles these on mobile/TV).
  static const MethodChannel _desktopUiChannel = MethodChannel(
    'ui_player_plugin_activity',
  );

  /// Native Player instance for Windows
  media_kit.Player? _mediaKitPlayer;

  media_kit.Player? get player => _mediaKitPlayer;

  /// VideoController for media_kit_video
  media_kit_video.VideoController? _videoController;

  media_kit_video.VideoController? get videoController => _videoController;

  VoidCallback? _sleepTimerExec;
  SaveSubtitleStyle? _saveSubtitleStyle;
  SaveClockSettings? _saveClockSettings;
  SavePlayerSettings? _savePlayerSettings;
  OnScreenshotTaken? _onScreenshotTaken;
  SearchExternalSubtitle? _searchExternalSubtitle;
  LabelSearchExternalSubtitle? _labelSearchExternalSubtitle;
  String? _findSubtitlesLabel;
  String? _findSubtitlesStateInfoLabel;
  SubtitleStyle _subtitleStyle = SubtitleStyle();
  ClockSettings _clockSettings = ClockSettings();
  PlayerSettings _playerSettings = PlayerSettings();

  /// The timeout duration for resolving a direct link via the `getDirectLink` callback.
  /// Defaults to 15 seconds if not explicitly set via [setConfig].
  Duration _directLinkTimeout = const Duration(seconds: 15);
  bool _isSearchingSubtitles = false;
  bool _isSavingWatchTime = false;

  /// Periodic timer that fires every 30 s on desktop to save watch progress
  /// (replaces the `onWatchTimeMarked` events that Android fires natively).
  Timer? _desktopWatchTimer;

  /// Callback for pagination. Triggered when the current playIndex
  /// is close to the end of the playlist.
  ///
  /// This callback is set via the [setConfig] method. Use it to fetch more data
  /// from your API and return it to be added to the player.
  ///
  /// Example of setting it in [setConfig]:
  /// ```dart
  /// controller.setConfig(
  ///   onLoadMore: () async {
  ///     final newItems = await fetchNextPage();
  ///     return newItems;
  ///   },
  /// );
  /// ```
  Future<List<PlaylistMediaItem>?> Function()? _onLoadMore;

  /// The number of items from the end of the playlist at which
  /// the [onLoadMore] callback (set via [setConfig]) should be triggered.
  ///
  /// For example, if set to 5, [onLoadMore] will be called when the player
  /// starts preparing the 5th item from the end of the current playlist.
  /// Defaults to 5. This value can be configured via [setConfig].
  int _paginationThreshold = 5;
  bool _isLoadingMore = false;

  /// The current overall state of the player.
  PlayerState _playerState = PlayerState();

  /// Gets the current overall state of the player.
  PlayerState get playerState => _playerState;

  /// The current playback-specific state (position, duration, etc.).
  PlaybackState _playbackState = PlaybackState();

  /// Gets the current playback-specific state.
  PlaybackState get playbackState => _playbackState;

  /// The metadata for the currently playing media item.
  MediaMetadata _currentMetadata = MediaMetadata();

  /// Gets the metadata for the currently playing media item.
  MediaMetadata get currentMetadata => _currentMetadata;

  /// Stream controller for the overall player state.
  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();

  /// A stream of [PlayerState] updates. Listen to this to get notified of
  /// changes in the player's state (e.g., playlist changes, errors, track updates).
  Stream<PlayerState> get playerStateStream => _stateController.stream;

  /// Stream controller for the playback state.
  final StreamController<PlaybackState> _playbackStateController =
      StreamController<PlaybackState>.broadcast();

  /// A stream of [PlaybackState] updates. Listen to this to get notified of
  /// changes in playback position, buffering, and duration.
  Stream<PlaybackState> get playbackStateStream =>
      _playbackStateController.stream;

  /// Stream controller for the media metadata.
  final StreamController<MediaMetadata> _mediaMetadataController =
      StreamController<MediaMetadata>.broadcast();

  /// A stream of [MediaMetadata] updates. Listen to this to get notified when
  /// the metadata of the current media item changes.
  Stream<MediaMetadata> get mediaMetadataStream =>
      _mediaMetadataController.stream;

  /// A map of localized strings passed from the main application.
  Map<String, String> _localeStrings = {};

  /// Sets the localized strings to be used by the player UI.
  set localeStrings(Map<String, String> value) {
    _localeStrings = value;
  }

  /// The singleton instance of the controller.
  static final FtvMedia3PlayerController _instance =
      FtvMedia3PlayerController._internal();

  /// Factory constructor to return the singleton instance.
  factory FtvMedia3PlayerController() => _instance;

  /// Internal constructor to initialize the method call handlers.
  FtvMedia3PlayerController._internal() {
    _setMethodCallHandler(_handleMethodCall);
    _setPluginMethodCallHandler(_handleMethodCall);
    if (isDesktopOrWebPlayer) {
      // On desktop the overlay runs in the same Flutter engine, so its
      // outbound channel ('ui_player_plugin_activity') has no Android Activity
      // to receive it.  We intercept it here and apply changes to the MPV
      // player directly.
      _desktopUiChannel.setMethodCallHandler(_handleDesktopUiCall);
    }
  }

  void setConfig({
    Map<String, String>? localeStrings,
    SubtitleStyle? subtitleStyle,
    PlayerSettings? playerSettings,
    ClockSettings? clockSettings,
    SaveSubtitleStyle? saveSubtitleStyle,
    SaveClockSettings? saveClockSettings,
    SavePlayerSettings? savePlayerSettings,
    OnScreenshotTaken? onScreenshotTaken,
    VoidCallback? sleepTimerExec,
    SearchExternalSubtitle? searchExternalSubtitle,
    String? findSubtitlesLabel,
    String? findSubtitlesStateInfoLabel,
    LabelSearchExternalSubtitle? labelSearchExternalSubtitle,
    int? paginationThreshold,
    Duration? directLinkTimeout,
    Future<List<PlaylistMediaItem>?> Function()? onLoadMore,
  }) {
    if (localeStrings != null) this.localeStrings = localeStrings;
    if (subtitleStyle != null) _subtitleStyle = subtitleStyle;
    if (playerSettings != null) _playerSettings = playerSettings;
    if (clockSettings != null) _clockSettings = clockSettings;
    if (saveSubtitleStyle != null) _saveSubtitleStyle = saveSubtitleStyle;
    if (saveClockSettings != null) _saveClockSettings = saveClockSettings;
    if (savePlayerSettings != null) _savePlayerSettings = savePlayerSettings;
    if (onScreenshotTaken != null) _onScreenshotTaken = onScreenshotTaken;
    if (sleepTimerExec != null) _sleepTimerExec = sleepTimerExec;
    if (directLinkTimeout != null) _directLinkTimeout = directLinkTimeout;
    if (onLoadMore != null) _onLoadMore = onLoadMore;

    if (searchExternalSubtitle != null) {
      _searchExternalSubtitle = searchExternalSubtitle;
    }
    if (findSubtitlesLabel != null) _findSubtitlesLabel = findSubtitlesLabel;
    if (findSubtitlesStateInfoLabel != null) {
      _findSubtitlesStateInfoLabel = findSubtitlesStateInfoLabel;
    }
    if (labelSearchExternalSubtitle != null) {
      _labelSearchExternalSubtitle = labelSearchExternalSubtitle;
    }
    if (paginationThreshold != null) {
      _paginationThreshold = paginationThreshold;
    }

    // Update _playerSettings with final flags
    _playerSettings = _playerSettings.copyWith(
      paginationEnable: _onLoadMore != null,
      paginationThreshold: _paginationThreshold,
      screenshotsEnable: _onScreenshotTaken != null,
    );

    _updateState(_playerState.copyWith(playerSettings: _playerSettings));
  }

  /// Cleans up resources, closing stream controllers and removing method call handlers.
  void close() {
    _stateController.close();
    _playbackStateController.close();
    _mediaMetadataController.close();
    _activityChannel.setMethodCallHandler(null);
    _pluginChannel.setMethodCallHandler(null);
    if (isDesktopOrWebPlayer) {
      _desktopUiChannel.setMethodCallHandler(null);
    }
  }

  // ─── Desktop-only getters ────────────────────────────────────────────────

  /// The subtitle style currently configured for the player.
  /// On desktop this is used to pre-populate the overlay UI and to apply
  /// MPV properties when playback starts.
  SubtitleStyle get subtitleStyle => _subtitleStyle;

  /// The player settings currently configured.
  /// On desktop this is used to pre-populate the overlay UI and to apply
  /// MPV properties (e.g. `hwdec`) when playback starts.
  PlayerSettings get currentPlayerSettings => _playerSettings;

  String _formatErrorMessage(dynamic error) {
    if (error is TimeoutException) {
      return OverlayLocalizations.get('linkResolutionTimeout');
    }
    if (error is SocketException) {
      return OverlayLocalizations.get('linkResolutionNetworkError');
    }
    if (error is PlatformException) {
      return error.message ??
          OverlayLocalizations.get('linkResolutionUnknownError');
    }

    final msg = error.toString().replaceAll("Exception: ", "");
    return msg.isNotEmpty
        ? msg
        : OverlayLocalizations.get('linkResolutionUnknownError');
  }

  /// Handles incoming method calls from the native side.
  ///
  /// This method acts as a router, dispatching actions based on the method name
  /// received from the native player. It updates the player state accordingly.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    PlayerState newState = _playerState;
    switch (call.method) {
      case 'getMediaInfo':
        final index = call.arguments['index'] as int?;
        final requestId = MediaRequestManager.newRequest();

        try {
          if (index == null ||
              index < 0 ||
              index >= playerState.playlist.length) {
            throw PlatformException(
              code: 'INVALID_INDEX',
              message: 'Invalid playlist index: $index',
              details: null,
            );
          }

          PlaylistMediaItem item = playerState.playlist[index];
          if (!MediaRequestManager.isCurrentRequest(requestId)) {
            _sendLoadProgressToUI(
              state: 'Cancelled',
              progress: null,
              requestId: requestId,
            );
            return null;
          }

          if (item.getDirectLink != null) {
            _sendLoadProgressToUI(
              state: OverlayLocalizations.get('linkResolutionStart'),
              progress: null,
              requestId: requestId,
            );

            try {
              item = await item
                  .getDirectLink!(
                    item: item,
                    onProgress: _sendLoadProgressToUI,
                    requestId: requestId,
                  )
                  .timeout(_directLinkTimeout);

              if (!MediaRequestManager.isCurrentRequest(requestId)) {
                _sendLoadProgressToUI(
                  state: 'Cancelled',
                  progress: null,
                  requestId: requestId,
                );
                return null;
              }
            } catch (e) {
              if (MediaRequestManager.isCurrentRequest(requestId)) {
                final errorMessage = _formatErrorMessage(e);
                _sendLoadProgressToUI(
                  state:
                      "${OverlayLocalizations.get('errorPrefix')} $errorMessage",
                  progress: null,
                  requestId: requestId,
                );
                // Wait a bit so the user can see the error
                await Future.delayed(const Duration(seconds: 2));
                _updateState(_playerState.copyWith(activityReady: true));
              }
              throw PlatformException(
                code: 'DIRECT_LINK_ERROR',
                message: e.toString(),
              );
            }
          }
          if (!MediaRequestManager.isCurrentRequest(requestId)) {
            _sendLoadProgressToUI(
              state: 'Cancelled',
              progress: null,
              requestId: requestId,
            );
            return null;
          }

          _sendLoadProgressToUI(
            state: 'Link loaded',
            progress: null,
            requestId: requestId,
          );
          _updateState(
            _playerState.copyWith(activityReady: true, playIndex: index),
          );
          return item.toMap();
        } catch (e) {
          if (!MediaRequestManager.isCurrentRequest(requestId)) {
            _sendLoadProgressToUI(
              state: 'Cancelled',
              progress: null,
              requestId: requestId,
            );
            return null;
          }
          rethrow;
        }

      case 'onFindSubtitlesRequested':
        if (_isSearchingSubtitles) {
          break; // Ignore if a search is already in progress
        }
        _isSearchingSubtitles = true;

        // Create a base state that preserves the button's visibility and label
        final baseFindState = FindSubtitlesState(
          isVisible: _searchExternalSubtitle != null,
          label: _findSubtitlesLabel,
          stateInfoLabel: _findSubtitlesStateInfoLabel,
        );

        try {
          final mediaId = call.arguments['mediaId'] as String?;
          if (_searchExternalSubtitle == null) {
            break;
          }
          if (mediaId == null) {
            _updateFindSubtitlesState(
              baseFindState.copyWith(
                status: SubtitleSearchStatus.error,
                errorMessage: 'Error: mediaId is null.',
              ),
            );
            break;
          }

          try {
            final List<MediaItemSubtitle>? foundSubtitles =
                await _searchExternalSubtitle!(id: mediaId);
            _findSubtitlesStateInfoLabel =
                _labelSearchExternalSubtitle != null
                    ? await _labelSearchExternalSubtitle!()
                    : _findSubtitlesStateInfoLabel;
            if (foundSubtitles != null && foundSubtitles.isNotEmpty) {
              await setExternalSubtitles(subtitleTracks: foundSubtitles);
              // The UI will show its own success notification when the track list updates.
              // We just reset the state to idle.
              _updateFindSubtitlesState(
                baseFindState.copyWith(
                  status: SubtitleSearchStatus.idle,
                  stateInfoLabel: _findSubtitlesStateInfoLabel,
                ),
              );
            } else {
              _updateFindSubtitlesState(
                baseFindState.copyWith(
                  status: SubtitleSearchStatus.error,
                  errorMessage: 'No subtitles found.',
                  stateInfoLabel: _findSubtitlesStateInfoLabel,
                ),
              );
            }
          } catch (e) {
            _updateFindSubtitlesState(
              baseFindState.copyWith(
                status: SubtitleSearchStatus.error,
                errorMessage: 'Error searching subtitles: ${e.toString()}',
              ),
            );
          }
        } finally {
          _isSearchingSubtitles = false;
        }
        break;

      case 'onExternalSubtitleSelected':
        if (_findSubtitlesStateInfoLabel != null) {
          await updateFindSubtitlesStateInfoLabel();
        }
        break;

      case 'onWatchTimeMarked':
        if (_isSavingWatchTime) break;
        _isSavingWatchTime = true;
        try {
          final index = call.arguments['playlist_index'] as int?;
          final int durationMs = call.arguments['duration_ms'] as int? ?? 0;
          final int positionMs = call.arguments['position_ms'] as int? ?? 0;

          if (index != null &&
              index >= 0 &&
              index < _playerState.playlist.length) {
            PlaylistMediaItem item = _playerState.playlist[index];
            if (item.saveWatchTime != null) {
              final durationSec = (durationMs / 1000).round().toInt();
              int positionSec = (positionMs / 1000).round().toInt();
              if (durationSec == 0) return;
              if (positionSec > durationSec) positionSec = durationSec;
              await item.saveWatchTime!(
                id: item.id,
                duration: durationSec,
                position: positionSec,
                playIndex: index,
              );
            }
          }
        } finally {
          _isSavingWatchTime = false;
        }
        break;
      case 'onScreenshotTaken':
        final bytes = call.arguments['bytes'] as Uint8List?;
        final playlistIndex = call.arguments['playlistIndex'] as int?;
        if (bytes != null &&
            playlistIndex != null &&
            _onScreenshotTaken != null) {
          PlaylistMediaItem item = _playerState.playlist[playlistIndex];
          _onScreenshotTaken!(bytes: bytes, item: item);
        }
        break;
      case 'sleepTimerExec':
        if (_isSavingWatchTime) {
          if (_sleepTimerExec != null) _sleepTimerExec!();
          break;
        }
        _isSavingWatchTime = true;
        try {
          final index = _playerState.playIndex;
          if (index >= 0 && index < _playerState.playlist.length) {
            PlaylistMediaItem item = _playerState.playlist[index];
            if (item.saveWatchTime != null) {
              final durationSec = _playbackState.duration;
              int? positionSec = _playbackState.position;
              if (durationSec > 0) {
                if (_playerState.stateValue == StateValue.ended) {
                  positionSec = durationSec;
                }
                if (positionSec > durationSec) positionSec = durationSec;
                await item.saveWatchTime!(
                  id: item.id,
                  duration: durationSec,
                  position: positionSec,
                  playIndex: index,
                );
              }
            }
          }
        } finally {
          _isSavingWatchTime = false;
          if (_sleepTimerExec != null) _sleepTimerExec!();
        }
        break;
      case 'onLoadMore':
        if (_onLoadMore != null && !_isLoadingMore) {
          _isLoadingMore = true;
          try {
            final items = await _onLoadMore!();
            if (items != null && items.isNotEmpty) {
              await addMediaItems(items: items);
            }
          } finally {
            _isLoadingMore = false;
          }
        }
        break;
      case 'onError':
        newState = newState.copyWith(
          lastError:
              call.arguments['message'] as String? ??
              'An unknown playback error occurred.',
          errorCode: call.arguments['code'] as String?,
        );
        _updateState(newState);
        break;
      case 'updateSubtitleStyle':
        final styleSettingsMap = call.arguments as Map<dynamic, dynamic>?;
        if (styleSettingsMap != null) {
          final styleSettings = SubtitleStyle.fromMap(styleSettingsMap);
          if (_saveSubtitleStyle != null) {
            _saveSubtitleStyle!(subtitleStyle: styleSettings);
          }
        }
        _updateState(newState);
        break;
      case 'saveClockSettings':
        final clockSettingsStr = call.arguments['clock_settings'] as String?;
        if (_saveClockSettings != null) {
          final clockSettingsMap =
              clockSettingsStr != null
                  ? jsonDecode(clockSettingsStr) as Map<String, dynamic>
                  : null;
          final clockSettings =
              clockSettingsMap != null
                  ? ClockSettings.fromMap(clockSettingsMap)
                  : ClockSettings();
          _saveClockSettings!(clockSettings: clockSettings);
        }
        _updateState(newState);
        break;
      case 'savePlayerSettings':
        final playerSettingsMap = call.arguments as Map<dynamic, dynamic>?;
        if (_savePlayerSettings != null) {
          final playerSettings =
              playerSettingsMap != null
                  ? PlayerSettings.fromMap(playerSettingsMap)
                  : PlayerSettings();
          _savePlayerSettings!(playerSettings: playerSettings);
        }
        _updateState(newState);
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

      case 'onActivityReady':
        final playIndex = call.arguments['playlist_index'] as int? ?? 0;
        final Map<dynamic, dynamic>? subtitleStyleMap =
            call.arguments['subtitle_style'];
        final subtitleStyle =
            subtitleStyleMap != null
                ? SubtitleStyle.fromMap(subtitleStyleMap)
                : null;
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

        newState = newState.copyWith(
          activityReady: true,
          playIndex: playIndex,
          subtitleStyle: subtitleStyle,
          clockSettings: clockSettings,
          playerSettings: playerSettings,
          volumeState: volumeState,
        );
        _updateState(newState);
        break;

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
        }
        _updateState(newState);
        break;

      case 'onActivityDestroyed':
        newState = PlayerState(activityDestroyed: true);
        _updateState(newState);
        break;
      case 'onBack':
        break;
      case 'loadMediaInfo':
        final playIndex = call.arguments['playlist_index'] as int?;
        newState = PlayerState().copyWith(
          //RESET STATE FOR NEW INDEX
          playIndex: playIndex,
          playlist: newState.playlist,
          clockSettings: newState.clockSettings,
          playerSettings: newState.playerSettings,
        );
        _updatePlaybackState(PlaybackState());
        _updateState(newState);

        // Pagination logic
        if (playIndex != null &&
            _onLoadMore != null &&
            !_isLoadingMore &&
            newState.playlist.length - playIndex <= _paginationThreshold) {
          _isLoadingMore = true;
          _onLoadMore!()
              .then((items) {
                if (items != null && items.isNotEmpty) {
                  addMediaItems(items: items);
                }
              })
              .whenComplete(() {
                _isLoadingMore = false;
              });
        }
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
        _updateState(newState);
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
        _updateState(newState);
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
        _updateState(newState);
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
        _updateState(newState);
        break;
      case "setRepeatMode":
        final repeat = call.arguments['mode'] as String?;
        if (repeat == null) {
          newState = newState.copyWith(
            lastError: 'Null speed value in response',
            errorCode: 'SET_REPEAT_MODE',
          );
          return;
        }
        newState = newState.copyWith(
          repeatMode: PlayerRepeatMode.fromString(repeat),
        );
        _updateState(newState);
        break;
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
      case 'onStateChanged':
        final stateValue = call.arguments['state'] as String?;
        final isLive = call.arguments['isLive'] as bool? ?? false;
        final isSeekable = call.arguments['isSeekable'] as bool? ?? false;
        final playIndex = call.arguments['playlist_index'] as int? ?? 0;
        final speed = (call.arguments['speed'] as num?)?.toDouble();
        final repeatMode = call.arguments['repeatMode'] as String?;
        final shuffleEnabled =
            call.arguments['shuffleEnabled'] as bool? ?? false;
        newState = newState.copyWith(
          stateValue: StateValue.fromString(stateValue),
          isLive: isLive,
          isSeekable: isSeekable,
          playIndex: playIndex,
          speed: speed,
          repeatMode: PlayerRepeatMode.fromString(repeatMode),
          isShuffleModeEnabled: shuffleEnabled,
        );
        _updateState(newState);
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
        _updateState(newState);
        break;
      default:
        final err =
            "UNKNOWN_NATIVE_METHOD: ${call.method} with args: ${call.arguments}";
        _updateState(_playerState.copyWith(lastError: err));
        _updateState(newState);
    }
  }

  /// Sends the progress of loading media information to the UI.
  Future<void> _sendLoadProgressToUI({
    required String state,
    double? progress,
    required int requestId,
  }) async {
    if (requestId == MediaRequestManager.currentRequestId) {
      await _invokeMethodGuarded<void>(_activityChannel, 'loadMediaInfoState', {
        "state": state,
        "progress": progress,
      });
    }
  }

  /// Opens the player screen with a given playlist.
  ///
  /// This method pushes the [Media3PlayerScreen] onto the navigation stack
  /// and prepares the player state with the provided playlist.
  Future<void> openPlayer({
    required BuildContext context,
    required List<PlaylistMediaItem> playlist,
    int initialIndex = 0,
    Widget? playerLabel,
    Widget? placeholderWidget,
  }) async {
    OverlayLocalizations.load(_localeStrings);
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => Media3PlayerScreen(
          playerLabel: playerLabel,
          playlist: playlist,
          initialIndex: initialIndex,
          placeholderWidget: placeholderWidget,
        ),
      ),
    );
  }

  /// Closes the player and disposes player instance resources on Windows.
  Future<void> closePlayer() async {
    if (isDesktopOrWebPlayer) {
      // Cancel the periodic watch-time timer and do a final save.
      _desktopWatchTimer?.cancel();
      _desktopWatchTimer = null;
      await _saveDesktopWatchTime();
      if (_mediaKitPlayer != null) {
        await _mediaKitPlayer!.dispose();
        _mediaKitPlayer = null;
        _videoController = null;
      }
    }
  }

  // ─── Desktop / MPV helpers ───────────────────────────────────────────────

  /// Saves the current watch-time progress for the active playlist item on
  /// desktop.  Mirrors what the Android `onWatchTimeMarked` event does.
  Future<void> _saveDesktopWatchTime() async {
    if (_isSavingWatchTime) return;
    _isSavingWatchTime = true;
    try {
      final playlist = _playerState.playlist;
      final index = _playerState.playIndex;
      if (index < 0 || index >= playlist.length) return;
      final item = playlist[index];
      if (item.saveWatchTime == null) return;

      final durationSec = _playbackState.duration;
      int positionSec = _playbackState.position;
      if (durationSec == 0 || positionSec <= 5) return;
      if (positionSec > durationSec) positionSec = durationSec;

      await item.saveWatchTime!(
        id: item.id,
        duration: durationSec,
        position: positionSec,
        playIndex: index,
      );
    } catch (_) {
      // Silently ignore — never crash the player over a save failure.
    } finally {
      _isSavingWatchTime = false;
    }
  }

  /// Handles method calls from the overlay UI channel on desktop.
  ///
  /// The overlay sends commands to `'ui_player_plugin_activity'` which normally
  /// goes to the Android activity. On desktop we intercept them here and apply
  /// the changes directly to the media_kit (MPV) player.
  Future<dynamic> _handleDesktopUiCall(MethodCall call) async {
    switch (call.method) {
      case 'savePlayerSettings':
        final map = call.arguments as Map<dynamic, dynamic>?;
        final settings =
            map != null ? PlayerSettings.fromMap(map) : PlayerSettings();
        _playerSettings = settings;
        await _applyPlayerSettingsToMpv();
        _updateState(_playerState.copyWith(playerSettings: settings));
        if (_savePlayerSettings != null) {
          _savePlayerSettings!(playerSettings: settings);
        }
        break;

      case 'setSubtitleStyle':
        final map = call.arguments as Map<dynamic, dynamic>?;
        if (map != null) {
          final style = SubtitleStyle.fromMap(map);
          _subtitleStyle = style;
          await _applySubtitleStyleToMpv();
          _updateState(_playerState.copyWith(subtitleStyle: style));
          if (_saveSubtitleStyle != null) {
            _saveSubtitleStyle!(subtitleStyle: style);
          }
        }
        break;

      case 'saveClockSettings':
        final clockStr = call.arguments?['clock_settings'] as String?;
        if (_saveClockSettings != null && clockStr != null) {
          final clockSettings =
              ClockSettings.fromMap(jsonDecode(clockStr));
          _saveClockSettings!(clockSettings: clockSettings);
        }
        break;
    }
  }

  /// Converts the app's `#AARRGGBB` color format to MPV's expected
  /// `#RRGGBBAA` format.
  String _toMpvColor(String? argbHex) {
    if (argbHex == null || argbHex.isEmpty) return '#FFFFFFFF';
    final hex = argbHex.startsWith('#') ? argbHex.substring(1) : argbHex;
    if (hex.length == 8) {
      final aa = hex.substring(0, 2);
      final rrggbb = hex.substring(2);
      return '#$rrggbb$aa';
    }
    return '#FFFFFFFF';
  }

  /// Applies the current [_subtitleStyle] to the live MPV player instance.
  Future<void> _applySubtitleStyleToMpv() async {
    if (_mediaKitPlayer == null) return;
    try {
      if (_mediaKitPlayer!.platform is! media_kit.NativePlayer) return;
      final native = _mediaKitPlayer!.platform as media_kit.NativePlayer;
      final s = _subtitleStyle;

      await native.setProperty(
          'sub-color', _toMpvColor(s.foregroundColor?.hexString));
      await native.setProperty(
          'sub-back-color', _toMpvColor(s.backgroundColor?.hexString));

      final scale = s.textSizeFraction ?? 1.0;
      await native.setProperty('sub-scale', scale.toString());

      if (s.fontFamily != null && s.fontFamily!.isNotEmpty) {
        await native.setProperty('sub-font', s.fontFamily!);
      }
      final isBold = s.fontWeight == 'bold' || s.fontWeight == 'bold_italic';
      final isItalic = s.fontWeight == 'italic' || s.fontWeight == 'bold_italic';

      if (isBold) {
        await native.setProperty('sub-bold', 'yes');
      } else {
        await native.setProperty('sub-bold', 'no');
      }

      if (isItalic) {
        await native.setProperty('sub-italic', 'yes');
      } else {
        await native.setProperty('sub-italic', 'no');
      }

      if (s.positionPercentage != null) {
        await native.setProperty('sub-pos', s.positionPercentage!.toString());
      }

      final edgeColor = _toMpvColor(s.edgeColor?.hexString);
      switch (s.edgeType) {
        case SubtitleEdgeType.none:
          await native.setProperty('sub-border-size', '0');
          await native.setProperty('sub-shadow-offset', '0');
          break;
        case SubtitleEdgeType.outline:
        case SubtitleEdgeType.raised:
        case SubtitleEdgeType.depressed:
          await native.setProperty('sub-border-size', '3');
          await native.setProperty('sub-border-color', edgeColor);
          await native.setProperty('sub-shadow-offset', '0');
          break;
        case SubtitleEdgeType.dropShadow:
          await native.setProperty('sub-border-size', '1');
          await native.setProperty('sub-shadow-offset', '2');
          await native.setProperty('sub-shadow-color', edgeColor);
          break;
        default:
          break;
      }

      final bottom = s.bottomPadding;
      final left = s.leftPadding;
      if (bottom != null) {
        await native.setProperty('sub-margin-y', bottom.toString());
      }
      if (left != null) {
        await native.setProperty('sub-margin-x', left.toString());
      }
    } catch (_) {
      // Player may not be fully initialised yet; silently ignore.
    }
  }

  /// Applies hardware-decoding and other player settings to the live MPV
  /// player instance.
  Future<void> _applyPlayerSettingsToMpv() async {
    if (_mediaKitPlayer == null) return;
    try {
      if (_mediaKitPlayer!.platform is! media_kit.NativePlayer) return;
      final native = _mediaKitPlayer!.platform as media_kit.NativePlayer;
      await native.setProperty(
          'hwdec', _playerSettings.hardwareDecoding.mpvValue);
    } catch (_) {
      // Silently ignore.
    }
  }

  /// Triggers the native Android player activity to open.
  ///
  /// This method serializes the playlist and settings and sends them to the
  /// native side via the method channel to launch the player activity.
  Future<void> openNativePlayer({
    required List<PlaylistMediaItem> playlist,
    int initialIndex = 0,
  }) async {
    _playerState = PlayerState();
    if (playlist.isEmpty) {
      _updateState(
        _playerState.copyWith(lastError: "Cannot open empty playlist."),
      );
      return;
    }
    if (initialIndex < 0 || initialIndex >= playlist.length) {
      _updateState(
        _playerState.copyWith(
          lastError:
              "Invalid initial index ($initialIndex) for playlist of size ${playlist.length}.",
        ),
      );
      return;
    }
    _updateState(
      _playerState.copyWith(playlist: playlist, playIndex: initialIndex),
    );

    _playerSettings = _playerSettings.copyWith(
      paginationEnable: _onLoadMore != null,
      paginationThreshold: _paginationThreshold,
      screenshotsEnable: _onScreenshotTaken != null,
    );

    if (isDesktopOrWebPlayer) {
      if (_mediaKitPlayer != null) {
        await _mediaKitPlayer!.dispose();
      }
      _mediaKitPlayer = media_kit.Player();
      _videoController = media_kit_video.VideoController(
        _mediaKitPlayer!,
        configuration: media_kit_video.VideoControllerConfiguration(
          enableHardwareAcceleration:
              _playerSettings.hardwareDecoding != HardwareDecoding.disabled,
        ),
      );

      _mediaKitPlayer!.stream.position.listen((pos) {
        _updatePlaybackState(_playbackState.copyWith(position: pos.inSeconds));
      });
      _mediaKitPlayer!.stream.duration.listen((dur) {
        _updatePlaybackState(_playbackState.copyWith(duration: dur.inSeconds));
      });
      _mediaKitPlayer!.stream.playing.listen((playing) {
        _updateState(_playerState.copyWith(stateValue: playing ? StateValue.playing : StateValue.paused));
      });
      _mediaKitPlayer!.stream.completed.listen((completed) {
        if (completed) {
          _updateState(_playerState.copyWith(stateValue: StateValue.ended));
          _saveDesktopWatchTime(); // save on natural completion
        }
      });

      // Periodic watch-time save (every 30 s while playing).
      _desktopWatchTimer?.cancel();
      _desktopWatchTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _saveDesktopWatchTime(),
      );

      // Apply user-saved settings to the live MPV instance before opening the media.
      await _applyPlayerSettingsToMpv();
      await _applySubtitleStyleToMpv();

      final startPos = playlist[initialIndex].startPosition;
      await _mediaKitPlayer!.open(
        media_kit.Media(playlist[initialIndex].url),
        play: startPos == null || startPos <= 0,
      );
      if (startPos != null && startPos > 0) {
        await _mediaKitPlayer!.seek(Duration(seconds: startPos));
        await _mediaKitPlayer!.play();
      }

      // Push the initial settings into the state stream so the overlay UI
      // (which reads from playerStateStream) is pre-populated correctly.
      _updateState(
        _playerState.copyWith(
          subtitleStyle: _subtitleStyle,
          playerSettings: _playerSettings,
        ),
      );
      return;
    }

    final playlistMap = playlist.map((e) => e.toMap()).toList();
    final playlistStr = jsonEncode(playlistMap);
    final clockSettingsStr = jsonEncode(_clockSettings.toMap());

    final subtitleSearch =
        FindSubtitlesState(
          isVisible: _searchExternalSubtitle != null,
          label: _findSubtitlesLabel,
          stateInfoLabel: _findSubtitlesStateInfoLabel,
        ).toMap();

    try {
      await _invokeMethodGuarded<void>(_pluginChannel, 'openPlayer', {
        "playlist_index": initialIndex,
        "playlist_length": playlist.length,
        "playlist": playlistStr,
        "url": playlist[initialIndex].url,
        "subtitle_style": _subtitleStyle.toMap(),
        "clock_settings": clockSettingsStr,
        "player_settings": _playerSettings.toMap(),
        "locale_strings": jsonEncode(_localeStrings),
        "subtitle_search": jsonEncode(subtitleSearch),
        "stuck_buffering_detection_timeout_ms":
            _playerSettings.stuckBufferingDetectionTimeoutMs,
        "stuck_playing_detection_timeout_ms":
            _playerSettings.stuckPlayingDetectionTimeoutMs,
        "stuck_playing_not_ending_timeout_ms":
            _playerSettings.stuckPlayingNotEndingTimeoutMs,
        "stuck_suppressed_detection_timeout_ms":
            _playerSettings.stuckSuppressedDetectionTimeoutMs,
      });
      _updateState(_playerState.copyWith(playlist: playlist));
    } catch (e) {
      _updateState(_playerState.copyWith(lastError: "UNKNOWN_ERROR: $e"));
    }
  }

  /// Fetches a thumbnail or a specific frame from a media URI.
  ///
  /// [uri] The URI of the media item.
  /// [timeInSeconds] The time position in seconds for the frame. If null, a default thumbnail is extracted.
  /// Returns a [Uint8List] containing the PNG image data, or null on error.
  Future<Uint8List?> getVideoThumbnail(
    String uri, {
    double? timeInSeconds,
  }) async {
    final Map<String, dynamic> arguments = {'uri': uri};
    if (timeInSeconds != null && timeInSeconds >= 0) {
      arguments['timeInSeconds'] = timeInSeconds;
    }
    final Uint8List? result = await _invokeMethodGuarded(
      _pluginChannel,
      'getThumbnail',
      arguments,
    );
    return result;
  }

  /// Retrieves comprehensive media metadata for a given [uri] without starting playback.
  ///
  /// This method uses the native `MetadataRetriever` to extract information such as:
  /// - `durationSeconds`: Total duration of the media.
  /// - `totalTracks`: Number of available tracks.
  /// - `tracks`: A list of track information (video, audio, text) including mime types, codecs, resolution, etc.
  /// - `tags`: Metadata tags (e.g., ID3, Vorbis) if available.
  ///
  /// Returns a map containing the extracted metadata, or null if retrieval fails.
  Future<Map<String, dynamic>?> getMediaMetadata(String uri) async {
    final dynamic result = await _invokeMethodGuarded(
      _pluginChannel,
      'getMetadata',
      {'uri': uri},
    );
    return _castMap(result);
  }

  static Map<String, dynamic>? _castMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return data.map((key, value) {
        final String stringKey = key.toString();
        if (value is Map) {
          return MapEntry(stringKey, _castMap(value));
        }
        if (value is List) {
          return MapEntry(
            stringKey,
            value.map((e) => e is Map ? _castMap(e) : e).toList(),
          );
        }
        return MapEntry(stringKey, value);
      });
    }
    return null;
  }

  /// Updates the overall player state and notifies listeners if it has changed.
  void _updateState(PlayerState newState) {
    if (_playerState != newState) {
      _playerState = newState;
      if (!_stateController.isClosed) {
        _stateController.add(_playerState);
      }
    }
  }

  /// Updates the playback-specific state and notifies listeners.
  void _updatePlaybackState(PlaybackState newPlaybackState) {
    _playbackState = newPlaybackState;
    _playbackStateController.add(newPlaybackState);
  }

  /// Sets the method call handler for the activity channel.
  void _setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    _activityChannel.setMethodCallHandler(handler);
  }

  /// Sets the method call handler for the plugin channel.
  void _setPluginMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    _pluginChannel.setMethodCallHandler(handler);
  }

  /// A guarded wrapper for invoking method channel methods to handle exceptions.
  Future<T> _invokeMethodGuarded<T>(
    MethodChannel channel,
    String method, [
    dynamic arguments,
  ]) async {
    try {
      final T? result = await channel.invokeMethod<T>(method, arguments);
      return result as T;
    } on PlatformException catch (e, s) {
      throw AppPlayerException(
        'Platform error calling $method: ${e.message}',
        e,
        s,
      );
    } catch (e, s) {
      throw AppPlayerException('Error calling $method: $e', e, s);
    }
  }

  /// Toggles the player between play and pause states.
  Future<void> playPause() async {
    if (isDesktopOrWebPlayer && _mediaKitPlayer != null) {
      await _mediaKitPlayer!.playOrPause();
      return;
    }
    await _invokeMethodGuarded<void>(_activityChannel, 'playPause');
  }

  /// Starts or resumes playback.
  Future<void> play() async {
    if (isDesktopOrWebPlayer && _mediaKitPlayer != null) {
      await _mediaKitPlayer!.play();
      return;
    }
    await _invokeMethodGuarded<void>(_activityChannel, 'play');
  }

  /// Pauses playback.
  Future<void> pause() async {
    if (isDesktopOrWebPlayer && _mediaKitPlayer != null) {
      await _mediaKitPlayer!.pause();
      return;
    }
    await _invokeMethodGuarded<void>(_activityChannel, 'pause');
  }

  /// Seeks to a specific position in the current media item.
  ///
  /// [positionSeconds] The position to seek to, in seconds.
  Future<void> seekTo({required int positionSeconds}) async {
    if (isDesktopOrWebPlayer && _mediaKitPlayer != null) {
      await _mediaKitPlayer!.seek(Duration(seconds: positionSeconds));
      return;
    }
    await _invokeMethodGuarded<void>(_activityChannel, 'seekTo', {
      "position": positionSeconds * 1000,
    });
  }

  /// Sets the playback speed.
  Future<void> setSpeed({required double speed}) async {
    try {
      final result = await _invokeMethodGuarded<Map<Object?, Object?>>(
        _activityChannel,
        'setSpeed',
        {'speed': speed},
      );

      final speedValue = result['speed'] as double?;
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

  /// Sets the repeat mode for the player (off, one, all).
  Future<void> setRepeatMode({required PlayerRepeatMode repeatMode}) async {
    try {
      final result = await _invokeMethodGuarded<Map<Object?, Object?>>(
        _activityChannel,
        'setRepeatMode',
        {'mode': repeatMode.nativeValue},
      );

      final repeat = result['mode'] as String?;
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

  /// Enables or disables shuffle mode.
  Future<void> setShuffleMode(bool enabled) async {
    try {
      final result = await _invokeMethodGuarded<Map<Object?, Object?>>(
        _activityChannel,
        'setShuffleMode',
        {'enabled': enabled},
      );
      final shuffleEnabled = result['shuffleEnabled'] as bool?;
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

  /// Stops playback and releases player resources.
  Future<void> stop() async {
    if (isDesktopOrWebPlayer && _mediaKitPlayer != null) {
      if (_playbackState.position != null && _playbackState.duration != null) {
        // Sync watch history before disposing
        await _handleMethodCall(MethodCall('onWatchTimeMarked', {
          'playlist_index': _playerState.playIndex,
          'duration_ms': _playbackState.duration! * 1000,
          'position_ms': _playbackState.position! * 1000,
        }));
      }
      await _mediaKitPlayer!.stop();
      await _mediaKitPlayer!.dispose();
      _mediaKitPlayer = null;
      return;
    }
    await _invokeMethodGuarded<void>(_activityChannel, 'stop');
  }

  /// Sets the video zoom/resize mode.
  Future<void> setZoom({required PlayerZoom zoom}) async {
    if (playerState.zoom == PlayerZoom.scale) {
      await _invokeMethodGuarded<void>(_activityChannel, 'setScale');
    }
    await _executeZoomCommand('setResizeMode', {"mode": zoom.nativeValue});
  }

  /// Sets a custom scale for the video.
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

  /// Saves and applies new clock settings.
  Future<void> setClockSettings({ClockSettings? clockSettings}) async {
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

  /// Applies a new subtitle style.
  Future<void> updateSubtitleStyle({SubtitleStyle? subtitleStyle}) async {
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

  /// Saves and applies new player settings.
  Future<void> setPlayerSettings({PlayerSettings? playerSettings}) async {
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

  /// Helper to execute a zoom-related command and handle the result.
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

  /// Helper to process the result from a zoom command.
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

  /// Fetches the currently available tracks (video, audio, subtitle) from the player.
  Future<List<MediaTrack>> getCurrentTracks() async {
    final result = await _invokeMethodGuarded<dynamic>(
      _activityChannel,
      'getCurrentTracks',
    );
    final tracks = List<Map<String, dynamic>>.from(result);
    return tracks.map((track) => MediaTrack.fromMap(track)).toList();
  }

  /// Selects the specified audio track.
  Future<void> selectAudioTrack({AudioTrack? track}) async =>
      await _selectTrack(track);

  /// Selects the specified subtitle track.
  Future<void> selectSubtitleTrack({SubtitleTrack? track}) async =>
      await _selectTrack(track);

  /// Selects the specified video track.
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

  /// Helper to select a track of any type.
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

  /// Fetches the latest metadata from the player.
  Future<void> getMetaData() async {
    final result = await _invokeMethodGuarded<dynamic>(
      _activityChannel,
      'getMetadata',
    );
    final Map<Object?, Object?> resultMap = result;
    _currentMetadata = MediaMetadata.fromMap(resultMap);
    _mediaMetadataController.add(_currentMetadata);
  }

  /// Resets the last error state.
  void resetError() => _updateState(_playerState.copyWith(resetError: true));

  /// Skips to the next item in the playlist.
  Future<void> playNext() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'playNext');
  }

  /// Skips to the previous item in the playlist.
  Future<void> playPrevious() async {
    await _invokeMethodGuarded<void>(_activityChannel, 'playPrevious');
  }

  /// Plays the item at the specified index in the playlist.
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

  /// Adds new media items to the end of the current playlist.
  ///
  /// This method updates the [playerState] in the main app, notifies the
  /// native Android player about the new playlist length, and synchronizes
  /// the new items with the UI overlay (the separate Flutter Engine).
  ///
  /// This is the primary method for implementing pagination or allowing
  /// users to append content to their queue while the player is active.
  Future<void> addMediaItems({required List<PlaylistMediaItem> items}) async {
    final updatedPlaylist = List<PlaylistMediaItem>.from(_playerState.playlist)
      ..addAll(items);
    _updateState(_playerState.copyWith(playlist: updatedPlaylist));

    if (_playerState.activityReady) {
      final playlistMap = updatedPlaylist.map((e) => e.toMap()).toList();
      final playlistStr = jsonEncode(playlistMap);
      await _invokeMethodGuarded<void>(_activityChannel, 'updatePlaylist', {
        'playlist': playlistStr,
        'playlist_length': updatedPlaylist.length,
      });
    }
  }

  /// Removes an item from the playlist at the specified [index].
  ///
  /// This method performs the following:
  /// 1. Updates the local [playerState] playlist.
  /// 2. Notifies the native player to adjust its internal `playlistLength`.
  /// 3. If the removed item is before the currently playing item, the native
  ///    player automatically decrements its `playlistIndex` to maintain continuity.
  /// 4. If the currently playing item is removed, the player skips to the
  ///    next available item or closes if the list becomes empty.
  /// 5. Synchronizes the updated playlist with the UI overlay.
  Future<void> removeMediaItem({required int index}) async {
    if (index < 0 || index >= _playerState.playlist.length) return;

    final updatedPlaylist = List<PlaylistMediaItem>.from(_playerState.playlist)
      ..removeAt(index);
    _updateState(_playerState.copyWith(playlist: updatedPlaylist));

    if (_playerState.activityReady) {
      final playlistMap = updatedPlaylist.map((e) => e.toMap()).toList();
      final playlistStr = jsonEncode(playlistMap);
      await _invokeMethodGuarded<void>(_activityChannel, 'onItemRemoved', {
        'index': index,
        'playlist': playlistStr,
        'playlist_length': updatedPlaylist.length,
      });
    }
  }

  /// Sets external subtitle tracks for the current media item.
  Future<void> setExternalSubtitles({
    required List<MediaItemSubtitle> subtitleTracks,
  }) async {
    if (subtitleTracks.isNotEmpty) {
      final subtitleTracksMap = subtitleTracks.map((e) => e.toMap()).toList();
      await _invokeMethodGuarded<void>(
        _activityChannel,
        'setExternalSubtitles',
        {"subtitleTracks": subtitleTracksMap},
      );
    }
  }

  /// Sets external audio tracks for the current media item.
  Future<void> setExternalAudio({
    required List<MediaItemAudioTrack> audioTracks,
  }) async {
    if (audioTracks.isNotEmpty) {
      final subtitleTracksMap = audioTracks.map((e) => e.toMap()).toList();
      await _invokeMethodGuarded<void>(_activityChannel, 'setExternalAudio', {
        "audioTracks": subtitleTracksMap,
      });
    }
  }

  /// Sends a custom string to be displayed in the overlay.
  ///
  /// This string will be shown in the TimeLinePanel.
  Future<void> sendCustomInfoToOverlay(String text) async {
    if (_playerState.activityReady != true) return;
    await _invokeMethodGuarded<void>(_activityChannel, 'onReceiveInfoText', {
      'text': text,
    });
  }

  /// Sends the current state of the subtitle search to the UI overlay.
  Future<void> _updateFindSubtitlesState(FindSubtitlesState state) async {
    if (_playerState.activityReady != true) return;
    await _invokeMethodGuarded<void>(
      _activityChannel,
      'onSubtitleSearchStateChanged',
      state.toMap(),
    );
  }

  /// Updates the info label for the subtitle search state and notifies the UI.
  Future<void> updateFindSubtitlesStateInfoLabel() async {
    _findSubtitlesStateInfoLabel =
        _labelSearchExternalSubtitle != null
            ? await _labelSearchExternalSubtitle!()
            : _findSubtitlesStateInfoLabel;
    final updatedState = FindSubtitlesState(
      isVisible: _searchExternalSubtitle != null,
      label: _findSubtitlesLabel,
      stateInfoLabel: _findSubtitlesStateInfoLabel,
      status: SubtitleSearchStatus.idle,
    );
    await _updateFindSubtitlesState(updatedState);
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
    final map = result.map((key, value) => MapEntry(key.toString(), value));
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
    final current = result['current'] as int?;
    final max = result['max'] as int?;
    final isMute = result['isMute'] as bool?;
    final volume = (result['volume'] as num?)?.toDouble();
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
    throw AppPlayerException('Failed to parse volume data from native.');
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
    final isMute = result['isMute'] as bool?;
    if (isMute != null) {
      _updateState(
        _playerState.copyWith(
          volumeState: _playerState.volumeState.copyWith(isMute: isMute),
        ),
      );
    }
  }
}

/// A custom exception for errors originating from the FtvMedia3PlayerController.
class AppPlayerException implements Exception {
  final String message;
  final dynamic originalException;
  final StackTrace? originalStackTrace;
  AppPlayerException(
    this.message, [
    this.originalException,
    this.originalStackTrace,
  ]);

  @override
  String toString() {
    String result = 'AppPlayerException: $message';
    if (originalException != null) {
      result += '\nOriginal Exception: $originalException';
    }
    return result;
  }
}

/// A custom exception for network-related errors in the player.
class AppNetworkException extends AppPlayerException {
  AppNetworkException(super.message);
}

/// Manages request IDs to prevent race conditions when fetching media.
///
/// When a new media item is requested, a new ID is generated. If a response
/// arrives for a previous request, it can be ignored.
class MediaRequestManager {
  static int _lastRequestId = 0;

  /// The ID of the most recent request.
  static int get currentRequestId => _lastRequestId;

  /// Generates a new, unique request ID.
  static int newRequest() => ++_lastRequestId;

  /// Checks if the given [requestId] is the most current one.
  static bool isCurrentRequest(int requestId) => requestId == _lastRequestId;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import '../bloc/overlay_ui_bloc.dart';
import '../media_ui_service/media3_ui_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'components/audio_screen/audio_screen_widget.dart';
import 'components/clock_panel.dart';
import 'components/epg_screen/epg_screen.dart';
import 'components/horizontal_playlist_panel.dart';
import 'components/info_panel.dart';
import 'components/placeholder_widget.dart';
import 'components/screenshot_frame.dart';
import 'components/setup_panel.dart';
import 'components/setup_panel/audio_widget/audio_widget.dart';
import 'components/setup_panel/playlist_widget/playlist_widget.dart';
import 'components/setup_panel/settings_screen/settings_screen.dart';
import 'components/setup_panel/settings_screen/sleep_timer_widget.dart';
import 'components/setup_panel/subtitle_widget/subtitle_widget.dart';
import 'components/setup_panel/video_widget/video_widget.dart';
import 'components/simple_panel.dart';
import 'components/touch_controls_overlay.dart';
import 'components/widgets/player_error_widget.dart';
import 'components/widgets/show_side_sheet.dart';
import 'components/widgets/titled_panel_scaffold.dart';
import 'components/widgets/brand_loading_indicator.dart';

/// The root widget for the player's UI overlay, running in a separate
/// Flutter Engine.
///
/// This screen is the central hub for the entire interface that is overlaid
/// on top of the native video. It is responsible for:
/// - **UI State Management:** Uses [OverlayUiBloc] to determine which
///   panel (info, settings, error, etc.) should be displayed at any given time.
/// - **Component Assembly:** Renders the appropriate UI components
///   (`InfoPanel`, `SetupPanel`, `EpgScreen`, etc.) based on the current
///   state in the BLoC.
/// - **Input Handling:** Sets up global key press handlers (D-pad)
///   using `CallbackShortcuts` to control the player (pause, seek,
///   invoking panels).
/// - **Controller Interaction:** Uses [Media3UiController] to send commands
///   to the native player.
class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key, required this.controller});
  final Media3UiController controller;
  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  final debouncerThrottler = DebouncerThrottler();
  DateTime? _lastInfoPressTime;

  @override
  void initState() {
    widget.controller.onBackPressed = () {
      final bloc = context.read<OverlayUiBloc>();
      final panel = bloc.state.playerPanel;
      final isInitial =
          widget.controller.playerState.stateValue == StateValue.initial;

      if (bloc.state.sideSheetOpen == true) {
        Navigator.of(context).pop();
        return;
      }

      if (panel == PlayerPanel.placeholder) {
        widget.controller.stop();
        return;
      }

      if (panel == PlayerPanel.none) {
        widget.controller.stop();
        return;
      }

      if (isInitial) {
        final shouldShowPlaceholder = panel != PlayerPanel.placeholder;
        if (shouldShowPlaceholder) {
          bloc.add(SetActivePanel(playerPanel: PlayerPanel.placeholder));
        } else {
          widget.controller.stop();
        }
        return;
      }
      bloc.add(SetActivePanel(playerPanel: PlayerPanel.none));
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Future.delayed(Duration(milliseconds: 150));
      widget.controller.overlayEntryPointCalled();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OverlayUiBloc>();
    return PopScope(
      canPop: bloc.state.playerPanel == PlayerPanel.none && bloc.state.sideSheetOpen == false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (bloc.state.sideSheetOpen == true) {
          Navigator.of(context).pop();
        } else if (bloc.state.playerPanel != PlayerPanel.none) {
          bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
        } else {
          widget.controller.stop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {
            final currentPanel = bloc.state.playerPanel;
            if (currentPanel == PlayerPanel.none) {
              bloc.add(
                const SetActivePanel(playerPanel: PlayerPanel.touchOverlay),
              );
            } else {
              // If any panel is open (including the touch overlay), a tap closes it.
              bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
            }
          },
          onDoubleTap: _playPause,
          behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          // Horizontal drag should not work when the screen is locked.
          if (!bloc.state.isScreenLocked) {
            _handleHorizontalDrag(details: details);
          }
        },
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: BlocConsumer<OverlayUiBloc, OverlayUiState>(
            listener: (BuildContext context, OverlayUiState state) {
              if (state.playerPanel == PlayerPanel.sleep) {
                _openPanel(playerPanel: PlayerPanel.none);
                showSideSheet(
                  context: context,
                  bloc: bloc,
                  body: SleepTimerWidget(bloc: bloc, isAuto: true),
                );
              }
              if (state.playerPanel == PlayerPanel.epg) {
                _openPanel(playerPanel: PlayerPanel.none);
                showSideSheet(
                  context: context,
                  bloc: bloc,
                  body: EpgScreen(
                    bloc: bloc,
                    controller: widget.controller,
                    initialChannelId: widget.controller.playItem.id,
                    onChannelLaunch: (EpgChannel value) {
                      bloc.add(SetActivePanel(playerPanel: PlayerPanel.none));
                      widget.controller.playSelectedIndex(index: value.index);
                      Navigator.of(context).pop();
                    },
                    deviceLocale:
                        widget
                            .controller
                            .playerState
                            .playerSettings
                            .deviceLocale ??
                        const Locale('en', 'US'),
                  ),
                );
              }
            },
            buildWhen:
                (oldState, newState) =>
                    oldState.playerPanel != newState.playerPanel,
            builder: (context, state) {
              if (state.playerPanel == PlayerPanel.placeholder) {
                return CallbackShortcuts(
                  bindings: _placeholderBindings(),
                  child: PlaceholderWidget(controller: widget.controller),
                );
              }
              if (state.playerPanel == PlayerPanel.error &&
                  widget.controller.playerState.lastError != null) {
                if (state.sideSheetOpen == true) {
                  Navigator.of(context).pop();
                }
                return CallbackShortcuts(
                  bindings: _placeholderBindings(),
                  child: PlayerErrorWidget(
                    lastError: widget.controller.playerState.lastError!,
                    errorCode: widget.controller.playerState.errorCode,
                    onOpen: widget.controller.resetError,
                    onClose: () => _openPanel(playerPanel: PlayerPanel.none),
                    onNext: () => widget.controller.playNext(),
                    onExit: () => widget.controller.stop(),
                    onRetry: () {
                      final idx = widget.controller.playerState.playIndex;
                      if (idx >= 0 && idx < widget.controller.playerState.playlist.length) {
                         widget.controller.playSelectedIndex(index: idx);
                      }
                    },
                    onSwitchToVLC: () async {
                      final idx = widget.controller.playerState.playIndex;
                      if (idx >= 0 && idx < widget.controller.playerState.playlist.length) {
                        final uri = widget.controller.playerState.playlist[idx].url;
                        if (uri != null) {
                          final vlcUrl = uri.replaceFirst('http://', 'vlc://').replaceFirst('https://', 'vlc://');
                          try {
                            if (!await launchUrl(Uri.parse(vlcUrl))) {
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VLC is not installed.')));
                               }
                            }
                          } catch (e) {
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VLC is not installed.')));
                             }
                          }
                        }
                      }
                    },
                  ),
                );
              }

              if (state.playerPanel == PlayerPanel.setup) {
                bloc.add(const SetTouchMode(isTouch: false));
                return SetupPanel(
                  controller: widget.controller,
                  selSettingsTab: state.tabIndex,
                );
              }
              if (state.playerPanel == PlayerPanel.touchOverlay) {
                bloc.add(const SetTouchMode(isTouch: true));
                return TouchControlsOverlay(
                  controller: widget.controller,
                  takeScreenshot: _takeScreenshot,
                );
              }
              if (state.playerPanel == PlayerPanel.settings) {
                return Container(
                  color: AppTheme.backgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SettingsScreen(controller: widget.controller),
                  ),
                );
              }
              if (state.playerPanel == PlayerPanel.playlist) {
                return TitledPanelScaffold(
                  title: OverlayLocalizations.get('playlist'),
                  icon: Icons.playlist_play,
                  child: PlaylistWidget(controller: widget.controller),
                );
              }
              if (state.playerPanel == PlayerPanel.audio) {
                return TitledPanelScaffold(
                  title: OverlayLocalizations.get('audio'),
                  icon: Icons.audiotrack,
                  child: AudioWidget(controller: widget.controller),
                );
              }
              if (state.playerPanel == PlayerPanel.video) {
                return TitledPanelScaffold(
                  title: OverlayLocalizations.get('video'),
                  icon: Icons.video_library,
                  child: VideoWidget(controller: widget.controller),
                );
              }
              if (state.playerPanel == PlayerPanel.subtitle) {
                return TitledPanelScaffold(
                  title: OverlayLocalizations.get('subtitle'),
                  icon: Icons.subtitles,
                  child: SubtitleWidget(controller: widget.controller),
                );
              }
              if (state.playerPanel == PlayerPanel.horizontalPlaylist) {
                return CallbackShortcuts(
                  bindings: _generalBindings(),
                  child: HorizontalPlaylistPanel(
                    controller: widget.controller,
                    generalBindings: _generalBindings(),
                  ),
                );
              }
              if (_shouldShowAudioUI()) {
                return CallbackShortcuts(
                  bindings: _generalBindings(),
                  child: Focus(
                    autofocus: true,
                    child: Stack(
                      children: [
                        AudioPlayerTVScreen(controller: widget.controller),
                        ClockPanel(controller: widget.controller),
                      ],
                    ),
                  ),
                );
              }
              if (state.playerPanel == PlayerPanel.simple) {
                return CallbackShortcuts(
                  bindings: _simpleBindings(),
                  child: SimplePanel(controller: widget.controller),
                );
              }
              if (state.playerPanel == PlayerPanel.info) {
                return CallbackShortcuts(
                  bindings: _generalBindings(),
                  child: InfoPanel(controller: widget.controller),
                );
              }

              return CallbackShortcuts(
                bindings: _generalBindings(),
                child: Focus(
                  autofocus: true,
                  child: StreamBuilder<PlayerState>(
                    stream: widget.controller.playerStateStream,
                    initialData: widget.controller.playerState,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      if (playerState == null) return const SizedBox.shrink();
                      return Stack(
                        children: [
                          ClockPanel(controller: widget.controller),
                          Visibility(
                            visible: playerState.volumeState.isMute == true,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 32.0),
                                child: const Icon(
                                  Icons.volume_off,
                                  color: Colors.white,
                                  size: 48,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(2, 2),
                                    ),
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(-2, -2),
                                    ),
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(-2, 2),
                                    ),
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(2, -2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Visibility(
                            visible:
                                playerState.stateValue == StateValue.paused &&
                                playerState.videoTracks.isNotEmpty,
                            child: Center(
                              child: Icon(
                                Icons.pause,
                                color: Colors.white,
                                size: 140,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(2, 2),
                                  ),
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(-2, -2),
                                  ),
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(-2, 2),
                                  ),
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(2, -2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Visibility(
                            visible: playerState.stateValue == StateValue.buffering || playerState.stateValue == StateValue.initial,
                            child: Center(
                              child: SizedBox(
                                width: 150,
                                height: 150,
                                child: const BrandLoadingIndicator(color: Colors.white, size: 150),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  bool _shouldShowAudioUI() {
    final playerState = widget.controller.playerState;
    final playIndex = playerState.playIndex;
    final playlist = playerState.playlist;

    if (playIndex < 0 || playIndex >= playlist.length) {
      return false;
    }

    final currentItem = playlist[playIndex];
    final mimeType = currentItem.mediaItemType.name.toLowerCase();

    if (mimeType.startsWith('audio') == true) {
      return true;
    }

    // 2. Fallback check: for undefined or missing mimeType
    // Check that the player is in a stable state (not loading, buffering, or in error)
    final isPlayerStable =
        playerState.stateValue != StateValue.buffering &&
        playerState.stateValue != StateValue.initial &&
        playerState.loadingStatus == null &&
        playerState.lastError == null;

    if (Platform.isWindows) return false;

    return playerState.videoTracks.isEmpty && isPlayerStable;
  }

  Map<ShortcutActivator, VoidCallback> _placeholderBindings() {
    return {
      const SingleActivator(LogicalKeyboardKey.mediaStop): _stop,
      const SingleActivator(LogicalKeyboardKey.keyE): _stop,

      const SingleActivator(LogicalKeyboardKey.arrowUp):
          () => widget.controller.playNext(),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          () => _handleArrowDown(),
    };
  }

  Map<ShortcutActivator, VoidCallback> _simpleBindings() {
    // ── IMPORTANT ──────────────────────────────────────────────────────────────
    // Do NOT add arrowLeft / arrowRight / arrowUp / arrowDown here.
    // CallbackShortcuts fires *before* FocusNode.onKeyEvent in Flutter's event
    // dispatch chain.  If those keys are registered here they will be consumed
    // at the shortcut layer and will never reach the custom seek-bar's
    // FocusNode.onKeyEvent in TimeLinePanel — causing the "hijack" bug.
    //
    // All four arrow keys are handled exclusively inside TimeLinePanel's
    // FocusNode when the SimplePanel is visible.
    // ───────────────────────────────────────────────────────────────────────────
    final Map<ShortcutActivator, VoidCallback> map = {};

    // Keep non-arrow shortcuts from the general set.
    for (final entry in _generalBindings().entries) {
      final activator = entry.key;
      if (activator is SingleActivator) {
        if (activator.trigger == LogicalKeyboardKey.arrowLeft ||
            activator.trigger == LogicalKeyboardKey.arrowRight ||
            activator.trigger == LogicalKeyboardKey.arrowUp ||
            activator.trigger == LogicalKeyboardKey.arrowDown ||
            activator.trigger == LogicalKeyboardKey.select ||
            activator.trigger == LogicalKeyboardKey.enter ||
            activator.trigger == LogicalKeyboardKey.space) {
          continue; // skip — owned by TimeLinePanel's FocusNode and UI buttons
        }
      }
      map[activator] = entry.value;
    }
    return map;
  }

  Map<ShortcutActivator, VoidCallback> _generalBindings() {
    return {
      const SingleActivator(LogicalKeyboardKey.mediaStop): _stop,
      const SingleActivator(LogicalKeyboardKey.keyE): _stop,
      const SingleActivator(LogicalKeyboardKey.escape): _stop,
      const SingleActivator(LogicalKeyboardKey.backspace): _stop,

      const SingleActivator(LogicalKeyboardKey.contextMenu):
          () => _openPanel(playerPanel: PlayerPanel.setup),
      const SingleActivator(LogicalKeyboardKey.keyQ):
          () => _openPanel(playerPanel: PlayerPanel.setup),
      // Handle info button for screenshot, it also opens info panel on single press
      const SingleActivator(LogicalKeyboardKey.info): _handleInfoPress,
      const SingleActivator(LogicalKeyboardKey.keyW): _handleInfoPress,

      const SingleActivator(LogicalKeyboardKey.enter): () => _playPause(),
      const SingleActivator(LogicalKeyboardKey.space): () => _playPause(),
      const SingleActivator(LogicalKeyboardKey.select): () => _playPause(),
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
          () => _playPause(),
      const SingleActivator(LogicalKeyboardKey.mediaPause): () => _playPause(),

      const SingleActivator(LogicalKeyboardKey.digit0):
          () => _goToVideoPercentage(percentage: 0),
      const SingleActivator(LogicalKeyboardKey.digit1):
          () => _goToVideoPercentage(percentage: 0.1),
      const SingleActivator(LogicalKeyboardKey.digit2):
          () => _goToVideoPercentage(percentage: 0.2),
      const SingleActivator(LogicalKeyboardKey.digit3):
          () => _goToVideoPercentage(percentage: 0.3),
      const SingleActivator(LogicalKeyboardKey.digit4):
          () => _goToVideoPercentage(percentage: 0.4),
      const SingleActivator(LogicalKeyboardKey.digit5):
          () => _goToVideoPercentage(percentage: 0.5),
      const SingleActivator(LogicalKeyboardKey.digit6):
          () => _goToVideoPercentage(percentage: 0.6),
      const SingleActivator(LogicalKeyboardKey.digit7):
          () => _goToVideoPercentage(percentage: 0.7),
      const SingleActivator(LogicalKeyboardKey.digit8):
          () => _goToVideoPercentage(percentage: 0.8),
      const SingleActivator(LogicalKeyboardKey.digit9):
          () => _goToVideoPercentage(percentage: 0.9),

      const SingleActivator(LogicalKeyboardKey.arrowUp):
          () => widget.controller.playNext(),
      const SingleActivator(LogicalKeyboardKey.mediaTrackNext):
          () => widget.controller.playNext(),
      const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious):
          () => widget.controller.playPrevious(),
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          () => _handleArrowDown(),

      const SingleActivator(LogicalKeyboardKey.arrowLeft):
          () => _arrowRewind(action: -10),
      const SingleActivator(LogicalKeyboardKey.arrowRight):
          () => _arrowRewind(action: 10),
      const SingleActivator(LogicalKeyboardKey.mediaRewind):
          () => _arrowRewind(action: -10),
      const SingleActivator(LogicalKeyboardKey.mediaFastForward):
          () => _arrowRewind(action: 10),
      const SingleActivator(LogicalKeyboardKey.pageUp):
          () => _arrowRewind(action: 600),
      const SingleActivator(LogicalKeyboardKey.pageDown):
          () => _arrowRewind(action: -600),

      const SingleActivator(LogicalKeyboardKey.backspace): () => _clockRandom(),
    };
  }

  Future<void> _arrowRewind({required int action}) async {
    if (widget.controller.playItem.programs != null) {
      _openPanel(playerPanel: PlayerPanel.epg);
    }
    if (widget.controller.playerState.isLive == true) return;
    final bloc = context.read<OverlayUiBloc>();
    await debouncerThrottler.throttle(Duration(milliseconds: 200), () async {
      await _seekTo(action: action);
      bloc.add(
        const SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true),
      );
    });
  }

  Future<void> _handleHorizontalDrag({
    required DragUpdateDetails details,
  }) async {
    if (widget.controller.playerState.isLive == true) return;

    final seekOffset = details.delta.dx.round();
    final bloc = context.read<OverlayUiBloc>();

    await debouncerThrottler.throttle(
      const Duration(milliseconds: 50),
      () async {
        await _seekTo(action: seekOffset);
        bloc.add(
          const SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true),
        );
      },
    );
  }

  Future<void> _seekTo({required int action}) async {
    final position = widget.controller.playbackState.position;
    final duration = widget.controller.playbackState.duration;
    final seconds =
        position + action < 0
            ? 0
            : position + action > duration
            ? duration - 5
            : position + action;
    await widget.controller.seekTo(positionSeconds: seconds);
  }

  Future<void> _stop() async {
    await widget.controller.stop();
  }

  void _openPanel({required PlayerPanel playerPanel}) {
    final bloc = context.read<OverlayUiBloc>();
    if (bloc.state.sideSheetOpen == true) {
      Navigator.of(context).pop();
    }
    context.read<OverlayUiBloc>().add(
      SetActivePanel(
        playerPanel:
            bloc.state.playerPanel == playerPanel
                ? PlayerPanel.none
                : playerPanel,
      ),
    );
  }

  void _handleArrowDown() {
    final bloc = context.read<OverlayUiBloc>();
    if (bloc.state.playerPanel == PlayerPanel.horizontalPlaylist) {
      bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
      widget.controller.playPrevious();
    } else {
      bloc.add(
        const SetActivePanel(playerPanel: PlayerPanel.horizontalPlaylist),
      );
    }
  }

  Future<void> _playPause() async {
    final bloc = context.read<OverlayUiBloc>();
    await widget.controller.playPause();
    bloc.add(
      const SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true),
    );
  }

  void _goToVideoPercentage({required double percentage}) {
    if (widget.controller.playerState.isLive == true) return;
    final bloc = context.read<OverlayUiBloc>();
    final positionSeconds =
        widget.controller.playbackState.duration * percentage;
    widget.controller.seekTo(positionSeconds: positionSeconds.toInt());
    bloc.add(
      const SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true),
    );
  }

  void _clockRandom() {
    final bloc = context.read<OverlayUiBloc>();
    if (bloc.state.clockSettings.clockPosition == ClockPosition.random) {
      final clockPosition = ClockPosition.getRandomPosition();
      bloc.add(SetClockPosition(clockPosition: clockPosition));
    }
  }

  Future<void> _handleInfoPress() async {
    final now = DateTime.now();
    final screenshotsEnable =
        widget.controller.playerState.playerSettings.screenshotsEnable;

    if (_lastInfoPressTime == null ||
        now.difference(_lastInfoPressTime!) >
            const Duration(milliseconds: 800) ||
        !screenshotsEnable) {
      _lastInfoPressTime = now;
      _openPanel(playerPanel: PlayerPanel.info);
    } else {
      _lastInfoPressTime = null;
      await _takeScreenshot();
    }
  }

  Future<void> _takeScreenshot() async {
    final overlay = Overlay.of(context);
    final playerState = widget.controller.playerState;
    final playIndex = playerState.playIndex;
    final playlist = playerState.playlist;
    final playItem = playlist[playIndex];

    context.read<OverlayUiBloc>().add(
      const SetActivePanel(playerPanel: PlayerPanel.none),
    );
    final int positionMs = widget.controller.playbackState.position;
    final Uint8List? thumbnail = await widget.controller.getVideoThumbnail(
      widget.controller.playItem.url,
      timeInSeconds: positionMs.toDouble(),
    );

    if (thumbnail == null) {
      if (mounted) {
        _showSnack(OverlayLocalizations.get('screenshotFailed'), isError: true);
      }
      return;
    }

    final overlayEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 100),
                tween: Tween(begin: 0.0, end: 1.0),
                builder:
                    (context, value, child) => Container(
                      color: Colors.white.withValues(
                        alpha: 0.3 * (1.0 - value),
                      ),
                    ),
              ),
              IgnorePointer(
                child: ScreenshotFrame(bytes: thumbnail, title: playItem.title),
              ),
            ],
          ),
    );

    overlay.insert(overlayEntry);
    await Future.delayed(const Duration(milliseconds: 2000));
    overlayEntry.remove();

    if (mounted) {
      _showSnack(OverlayLocalizations.get('screenshotSuccess'));
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppTheme.errColor : AppTheme.focusColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


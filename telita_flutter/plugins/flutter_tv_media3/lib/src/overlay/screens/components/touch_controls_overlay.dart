import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import '../../bloc/overlay_ui_bloc.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'time_line_panel.dart';

class TouchControlsOverlay extends StatefulWidget {
  const TouchControlsOverlay({
    super.key,
    required this.controller,
    required this.takeScreenshot,
  });
  final VoidCallback takeScreenshot;
  final Media3UiController controller;

  @override
  State<TouchControlsOverlay> createState() => _TouchControlsOverlayState();
}

class _TouchControlsOverlayState extends State<TouchControlsOverlay> {
  Timer? _hideTimer;
  double _opacity = 0;
  @override
  void initState() {
    super.initState();
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _opacity = 1;
      });
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted &&
          context.read<OverlayUiBloc>().state.playerPanel ==
              PlayerPanel.touchOverlay) {
        if (widget.controller.playerState.stateValue == StateValue.paused) {
          return;
        }
        setState(() {
          _opacity = 0;
        });
      }
    });
  }

  Future<void> _seek(int seconds) async {
    final newPosition = widget.controller.playbackState.position + seconds;
    final duration = widget.controller.playbackState.duration;
    if (newPosition >= 0 && newPosition <= duration) {
      await widget.controller.seekTo(positionSeconds: newPosition);
    }
    _startHideTimer();
  }

  void _goToVideoPercentage(double percentage) {
    if (widget.controller.playerState.isLive == true) return;
    final duration = widget.controller.playbackState.duration;
    final newPosition = (duration * percentage).toInt();
    widget.controller.seekTo(positionSeconds: newPosition);
    _startHideTimer();
  }

  Widget _buildPanelButton({
    required OverlayUiBloc bloc,
    required IconData icon,
    required PlayerPanel panel,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 32),
      onPressed: () {
        _startHideTimer();
        bloc.add(SetActivePanel(playerPanel: panel));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OverlayUiBloc>();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      onEnd: _closePanel,
      opacity: _opacity,
      child: GestureDetector(
        onTap: _startHideTimer,
        onPanDown: (_) => _startHideTimer(),
        child: BlocBuilder<OverlayUiBloc, OverlayUiState>(
          buildWhen:
              (previous, current) =>
                  previous.isScreenLocked != current.isScreenLocked,
          builder: (context, state) {
            final isLocked = state.isScreenLocked;
            if (isLocked) {
              _hideTimer?.cancel();
            } else {
              _startHideTimer();
            }

            return Material(
              type: MaterialType.transparency,
              child: StreamBuilder<PlayerState>(
                stream: widget.controller.playerStateStream,
                builder: (context, playerStateSnapshot) {
                  final playerState =
                      playerStateSnapshot.data ?? widget.controller.playerState;
                  final isPlaying =
                      playerState.stateValue == StateValue.playing;
                  final hasMultipleItems = playerState.playlist.length > 1;
                  return GestureDetector(
                    onTap:
                        () => setState(() {
                          _opacity = 0;
                        }),
                    child: Container(
                      color: isLocked ? null : AppTheme.backgroundColor,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Column(
                                    spacing: 25,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isLocked
                                              ? Icons.lock
                                              : Icons.lock_open,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        onPressed:
                                            () => bloc.add(
                                              const ToggleScreenLock(),
                                            ),
                                      ),
                                      Expanded(
                                        child: StreamBuilder<PlayerState>(
                                          stream:
                                              widget
                                                  .controller
                                                  .playerStateStream,
                                          initialData:
                                              widget.controller.playerState,
                                          builder: (context, snapshot) {
                                            final volumeState =
                                                snapshot.data?.volumeState;
                                            if (volumeState == null) {
                                              return const SizedBox.shrink();
                                            }

                                            return Visibility(
                                              visible: !isLocked,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      volumeState.isMute
                                                          ? Icons.volume_off
                                                          : volumeState
                                                                  .current >
                                                              0
                                                          ? Icons.volume_up
                                                          : Icons.volume_mute,
                                                      color: Colors.white,
                                                      size: 32,
                                                    ),
                                                    onPressed: () {
                                                      widget.controller
                                                          .toggleMute();
                                                      _startHideTimer();
                                                    },
                                                  ),
                                                  Expanded(
                                                    child: RotatedBox(
                                                      quarterTurns: 3,
                                                      child: Slider(
                                                        value:
                                                            volumeState.volume,
                                                        max: 1.0,
                                                        onChanged: (value) {
                                                          widget.controller
                                                              .setVolume(
                                                                volume: value,
                                                              );
                                                          _startHideTimer();
                                                        },
                                                        activeColor:
                                                            AppTheme
                                                                .fullFocusColor,
                                                        inactiveColor:
                                                            AppTheme
                                                                .colorPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.stop_circle,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        onPressed: () {
                                          _startHideTimer();
                                          widget.controller.stop();
                                        },
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    child: Visibility(
                                      visible: !isLocked,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.info_outline,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                            onPressed: () {
                                              _startHideTimer();
                                              bloc.add(
                                                const SetActivePanel(
                                                  playerPanel: PlayerPanel.info,
                                                ),
                                              );
                                            },
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (hasMultipleItems)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.skip_previous,
                                                    color: Colors.white,
                                                    size: 48,
                                                  ),
                                                  onPressed: () {
                                                    _startHideTimer();
                                                    widget.controller
                                                        .playPrevious();
                                                  },
                                                ),
                                              const SizedBox(width: 24),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.replay_10,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                                onPressed: () => _seek(-10),
                                              ),
                                              const SizedBox(width: 24),
                                              IconButton(
                                                icon: Icon(
                                                  isPlaying
                                                      ? Icons
                                                          .pause_circle_filled
                                                      : Icons
                                                          .play_circle_filled,
                                                  color: Colors.white,
                                                  size: 80,
                                                ),
                                                onPressed: () {
                                                  _startHideTimer();
                                                  widget.controller.playPause();
                                                },
                                              ),
                                              const SizedBox(width: 24),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.forward_10,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                                onPressed: () => _seek(10),
                                              ),
                                              const SizedBox(width: 24),
                                              if (hasMultipleItems)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.skip_next,
                                                    color: Colors.white,
                                                    size: 48,
                                                  ),
                                                  onPressed: () {
                                                    _startHideTimer();
                                                    widget.controller
                                                        .playNext();
                                                  },
                                                ),
                                            ],
                                          ),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: List.generate(10, (
                                                index,
                                              ) {
                                                final percentage = index / 10.0;
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4.0,
                                                      ),
                                                  child: OutlinedButton(
                                                    onPressed:
                                                        () =>
                                                            _goToVideoPercentage(
                                                              percentage,
                                                            ),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.white30,
                                                      side: const BorderSide(
                                                        color: Colors.white30,
                                                        width: 1.5,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${index * 10}%',
                                                      style: const TextStyle(
                                                        color: Colors.white30,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Visibility(
                                    visible: !isLocked,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Visibility(
                                          visible:
                                              widget
                                                  .controller
                                                  .playerState
                                                  .playerSettings
                                                  .screenshotsEnable,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _opacity = 0;
                                              });
                                              widget.takeScreenshot();
                                            },
                                          ),
                                        ),
                                        _buildPanelButton(
                                          bloc: bloc,
                                          icon: Icons.settings,
                                          panel: PlayerPanel.settings,
                                        ),
                                        _buildPanelButton(
                                          bloc: bloc,
                                          icon: Icons.playlist_play,
                                          panel: PlayerPanel.playlist,
                                        ),
                                        Visibility(
                                          visible:
                                              widget
                                                  .controller
                                                  .playItem
                                                  .programs !=
                                              null,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildPanelButton(
                                                bloc: bloc,
                                                icon: Icons.list_alt,
                                                panel: PlayerPanel.epg,
                                              ),
                                              const SizedBox(height: 16),
                                            ],
                                          ),
                                        ),
                                        _buildPanelButton(
                                          bloc: bloc,
                                          icon: Icons.video_settings,
                                          panel: PlayerPanel.video,
                                        ),
                                        _buildPanelButton(
                                          bloc: bloc,
                                          icon: Icons.audiotrack,
                                          panel: PlayerPanel.audio,
                                        ),
                                        _buildPanelButton(
                                          bloc: bloc,
                                          icon: Icons.subtitles,
                                          panel: PlayerPanel.subtitle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Visibility(
                              visible: !isLocked,
                              child: TimeLinePanel(
                                controller: widget.controller,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _closePanel() =>
      _opacity == 0
          ? context.read<OverlayUiBloc>().add(
            const SetActivePanel(playerPanel: PlayerPanel.none),
          )
          : null;
}

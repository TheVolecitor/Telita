import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tv_media3/src/app_theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/overlay_ui_bloc.dart';

import 'widgets/clock_widget.dart';
import '../../../entity/playback_state.dart';
import '../../../entity/player_state.dart';
import '../../../utils/string_utils.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'widgets/custom_info_text_widget.dart';

class TimeLinePanel extends StatefulWidget {
  final Media3UiController controller;
  const TimeLinePanel({super.key, required this.controller});

  @override
  State<TimeLinePanel> createState() => _TimeLinePanelState();
}

class _TimeLinePanelState extends State<TimeLinePanel> {
  double? _sliderPositionOnDrag;
  bool _isSliderFocused = false;
  late final FocusNode _sliderFocusNode;
  int _seekMultiplier = 0;
  Timer? _seekDebounceTimer;

  @override
  void initState() {
    super.initState();
    _sliderFocusNode = FocusNode();
    _sliderFocusNode.addListener(() {
      if (mounted) setState(() => _isSliderFocused = _sliderFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _seekDebounceTimer?.cancel();
    _sliderFocusNode.dispose();
    super.dispose();
  }

  final style = const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    fontSize: 18,
  );

  @override
  Widget build(BuildContext context) {
    final bool isLive = widget.controller.playerState.isLive;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          context.read<OverlayUiBloc>().add(
                const SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true),
              );
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: StreamBuilder<PlaybackState>(
        stream: widget.controller.playbackStateStream,
        initialData: widget.controller.playbackState,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null || data.duration <= 0) {
            return const SizedBox.shrink();
          }

          final positionPercentage = StringUtils.getPercentage(
            duration: data.duration,
            position: data.position,
          );
          final effectivePosPercentage = _sliderPositionOnDrag ?? positionPercentage;
          final effectivePosSeconds = (effectivePosPercentage * data.duration).toInt();

          final bufferedPercentage = StringUtils.getPercentage(
            duration: data.duration,
            position: data.bufferedPosition,
          );

          final currentPosition = StringUtils.formatDuration(seconds: effectivePosSeconds);
          final totalDuration = StringUtils.formatDuration(seconds: data.duration);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: Title & Icons
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: isLive
                        ? const SizedBox.shrink()
                        : Text(
                            widget.controller.playerState.playlist.isNotEmpty
                                ? widget.controller.playerState.playlist[widget.controller.playerState.playIndex].title ?? ''
                                : '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  const ClockWidget(),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Middle: Custom TV Slider
              Focus(
                focusNode: _sliderFocusNode,
                autofocus: true,
                skipTraversal: false,
                descendantsAreFocusable: false,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                    switch (event.logicalKey) {
                      case LogicalKeyboardKey.arrowUp:
                      case LogicalKeyboardKey.arrowDown:
                        // Ignore up/down so Flutter's default D-pad traversal
                        // can automatically move focus to the top/bottom buttons
                        return KeyEventResult.ignored;

                      case LogicalKeyboardKey.arrowLeft:
                      case LogicalKeyboardKey.arrowRight:
                        final isRight = event.logicalKey == LogicalKeyboardKey.arrowRight;
                        final data = widget.controller.playbackState;
                        if (data.duration <= 0) return KeyEventResult.handled;

                        if (event is KeyDownEvent) {
                          _seekMultiplier = 1;
                        } else {
                          _seekMultiplier++;
                        }

                        double step = 10.0;
                        if (_seekMultiplier > 30) step = 60.0;
                        else if (_seekMultiplier > 15) step = 30.0;
                        else if (_seekMultiplier > 5) step = 20.0;

                        final currentSecs = (_sliderPositionOnDrag ?? (data.position / data.duration)) * data.duration;
                        final newSecs = (currentSecs + (isRight ? step : -step)).clamp(0.0, data.duration.toDouble());
                        setState(() => _sliderPositionOnDrag = newSecs / data.duration);
                        context.read<OverlayUiBloc>().add(const SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true));
                        return KeyEventResult.handled;

                      case LogicalKeyboardKey.select:
                      case LogicalKeyboardKey.enter:
                      case LogicalKeyboardKey.space:
                        if (event is KeyDownEvent) widget.controller.playPause();
                        context.read<OverlayUiBloc>().add(const SetActivePanel(playerPanel: PlayerPanel.simple, debounce: true));
                        return KeyEventResult.handled;
                    }
                  }

                  if (event is KeyUpEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                        event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      if (_sliderPositionOnDrag != null) {
                        final data = widget.controller.playbackState;
                        widget.controller.seekTo(
                          positionSeconds: (_sliderPositionOnDrag! * data.duration).toInt(),
                        );
                        _seekDebounceTimer?.cancel();
                        _seekDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                          if (mounted) setState(() => _sliderPositionOnDrag = null);
                        });
                      }
                      _seekMultiplier = 0;
                      return KeyEventResult.handled;
                    }
                  }

                  return KeyEventResult.ignored;
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final thumbRadius = _isSliderFocused ? 8.0 : 6.0;
                      final effectivePos = effectivePosPercentage.isNaN ? 0.0 : effectivePosPercentage.clamp(0.0, 1.0);
                      final bufferPos = bufferedPercentage.isNaN ? 0.0 : bufferedPercentage.clamp(0.0, 1.0);
                      final thumbCenter = (width * effectivePos).clamp(0.0, width);
                      
                      return Container(
                        height: 24,
                        alignment: Alignment.center,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.centerLeft,
                          children: [
                            // Background track
                            Container(
                              height: 4.0,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(2.0),
                              ),
                            ),
                            // Buffered track
                            FractionallySizedBox(
                              widthFactor: bufferPos,
                              child: Container(
                                height: 4.0,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(2.0),
                                ),
                              ),
                            ),
                            // Active track
                            FractionallySizedBox(
                              widthFactor: effectivePos,
                              child: Container(
                                height: 4.0,
                                decoration: BoxDecoration(
                                  color: AppTheme.fullFocusColor,
                                  borderRadius: BorderRadius.circular(2.0),
                                ),
                              ),
                            ),
                            // Thumb
                            Positioned(
                              left: thumbCenter - thumbRadius,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: thumbRadius * 2,
                                height: thumbRadius * 2,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: _isSliderFocused 
                                    ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                                    : [],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Bottom Row: Play/Pause and Times
              if (!isLive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      StreamBuilder<PlayerState>(
                        stream: widget.controller.playerStateStream,
                        initialData: widget.controller.playerState,
                        builder: (context, snapshot) {
                          final playerState = snapshot.data;
                          final isPaused = playerState?.stateValue == StateValue.paused;
                          return InkWell(
                            focusColor: Colors.white24,
                            canRequestFocus: true,
                            onTap: () {
                              widget.controller.playPause();
                              _sliderFocusNode.requestFocus();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Text(
                        currentPosition,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        totalDuration,
                        style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        focusColor: Colors.white24,
                        icon: const Icon(Icons.audiotrack, color: Colors.white),
                        onPressed: () => context.read<OverlayUiBloc>().add(const SetActivePanel(playerPanel: PlayerPanel.audio)),
                      ),
                      IconButton(
                        focusColor: Colors.white24,
                        icon: const Icon(Icons.subtitles, color: Colors.white),
                        onPressed: () => context.read<OverlayUiBloc>().add(const SetActivePanel(playerPanel: PlayerPanel.subtitle)),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      ),
    );
  }
}

class CustomThumbShape extends SliderComponentShape {
  final double thumbRadius;
  final double borderWidth;
  final double cornerRadius;

  const CustomThumbShape({
    this.thumbRadius = 10.0,
    this.borderWidth = 3.0,
    this.cornerRadius = 4.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final outerPaint =
        Paint()
          ..color = AppTheme.fullFocusColor
          ..style = PaintingStyle.fill;

    final innerPaint =
        Paint()
          ..color = AppTheme.colorPrimary
          ..style = PaintingStyle.fill;

    final outerRect = Rect.fromCenter(
      center: center,
      width: thumbRadius * 2,
      height: thumbRadius * 2,
    );
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      Radius.circular(cornerRadius),
    );

    final innerRect = outerRect.deflate(borderWidth);

    final innerCornerRadius = max(0.0, cornerRadius - borderWidth);
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(innerCornerRadius),
    );

    canvas.drawRRect(outerRRect, outerPaint);
    canvas.drawRRect(innerRRect, innerPaint);
  }
}

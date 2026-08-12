import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../entity/playback_state.dart';
import '../../../entity/media_segment.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'package:flutter_tv_media3/src/app_theme/app_theme.dart';

class SkipSegmentWidget extends StatefulWidget {
  final Media3UiController controller;
  const SkipSegmentWidget({super.key, required this.controller});

  @override
  State<SkipSegmentWidget> createState() => _SkipSegmentWidgetState();
}

class _SkipSegmentWidgetState extends State<SkipSegmentWidget> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: widget.controller.playbackStateStream,
      initialData: widget.controller.playbackState,
      builder: (context, snapshot) {
        final playback = snapshot.data;
        if (playback == null || playback.duration <= 0) return const SizedBox.shrink();

        final playerState = widget.controller.playerState;
        final playlist = playerState.playlist;
        if (playlist.isEmpty || playerState.playIndex < 0 || playerState.playIndex >= playlist.length) {
          return const SizedBox.shrink();
        }

        final segments = playlist[playerState.playIndex].segments;
        if (segments == null || segments.isEmpty) {
          return const SizedBox.shrink();
        }

        final currentSecs = playback.position;
        MediaSegment? active;
        for (final seg in segments) {
          final start = seg.startSec ?? 0;
          if (currentSecs >= start && currentSecs < seg.endSec) {
            active = seg;
            break;
          }
        }

        if (active == null) {
          return const SizedBox.shrink();
        }

        final label = active.type.toLowerCase() == 'intro' 
            ? 'Skip Intro' 
            : active.type.toLowerCase() == 'recap' 
                ? 'Skip Recap' 
                : active.type.toLowerCase() == 'credits'
                    ? 'Skip Credits'
                    : 'Skip ${active.type}';

        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120.0, right: 32.0), // Above timeline
            child: Focus(
              onFocusChange: (focused) => setState(() => _isFocused = focused),
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && 
                   (event.logicalKey == LogicalKeyboardKey.select || 
                    event.logicalKey == LogicalKeyboardKey.enter || 
                    event.logicalKey == LogicalKeyboardKey.space)) {
                  widget.controller.seekTo(positionSeconds: active!.endSec);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: InkWell(
                onTap: () {
                  widget.controller.seekTo(positionSeconds: active!.endSec);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isFocused ? AppTheme.fullFocusColor : Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isFocused ? Colors.white : Colors.white30,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: _isFocused ? Colors.black : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.skip_next,
                        color: _isFocused ? Colors.black : Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

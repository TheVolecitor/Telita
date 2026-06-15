import 'package:flutter/material.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import 'package:flutter_tv_media3/src/overlay/media_ui_service/media3_ui_controller.dart';
import 'package:sprintf/sprintf.dart';

import '../../widgets/marquee_title_widget.dart';

class PlaylistItemWidget extends StatefulWidget {
  const PlaylistItemWidget({
    super.key,
    required this.controller,
    required this.item,
    required this.index,
    required this.autofocus,
    required this.isActive,
  });

  final Media3UiController controller;
  final PlaylistMediaItem item;
  final int index;
  final bool autofocus;
  final bool isActive;

  @override
  State<PlaylistItemWidget> createState() => _PlaylistItemWidgetState();
}

class _PlaylistItemWidgetState extends State<PlaylistItemWidget> {
  bool isFocus = false;

  @override
  void initState() {
    super.initState();
    isFocus = widget.autofocus;
  }

  @override
  void didUpdateWidget(covariant PlaylistItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocus != oldWidget.autofocus ||
        widget.item.startPosition != oldWidget.item.startPosition) {
      setState(() {
        isFocus = widget.autofocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color backgroundColor =
        isFocus
            ? AppTheme.focusColor
            : widget.isActive
            ? AppTheme.focusColor.withValues(alpha: 0.3)
            : Colors.transparent;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        if (isFocus != hasFocus) {
          setState(() {
            isFocus = hasFocus;
          });
        }
      },
      child: InkWell(
        onTap: () {
          widget.controller.playSelectedIndex(index: widget.index);
        },
        borderRadius: AppTheme.borderRadius,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: backgroundColor),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              spacing: 12,
              children: [
                Icon(
                  _getIconForMediaType(),
                  size: 38,
                  color:
                      widget.isActive || isFocus
                          ? Colors.white
                          : Colors.white70,
                ),
                Expanded(
                  child: MarqueeWidget(
                    text:
                        widget.item.label ??
                        widget.item.title ??
                        sprintf(OverlayLocalizations.get('itemNumber'), [
                          widget.index,
                        ]),
                    focus: isFocus,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight:
                          widget.isActive || isFocus
                              ? FontWeight.w500
                              : FontWeight.w300,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final duration = widget.item.duration;
                    final position = widget.item.startPosition;
                    final percent =
                        (duration != null && duration > 0 && position != null)
                            ? (position / duration).clamp(0.0, 1.0)
                            : 0.0;
                    return SizedBox(
                      width: 110,
                      child:
                          position == null && duration == null
                              ? SizedBox.shrink()
                              : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: 3,
                                children: [
                                  duration == position ||
                                          duration == null ||
                                          percent > 0.95
                                      ? Icon(Icons.remove_red_eye)
                                      : Text(
                                        "${(percent * 100).toInt()}%",
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                                  LinearProgressIndicator(
                                    value:
                                        duration == 0 && position == 0
                                            ? 1
                                            : percent,
                                    color: AppTheme.fullFocusColor,
                                    backgroundColor: AppTheme.divider,
                                  ),
                                  duration == 0 && position == 0
                                      ? SizedBox.shrink()
                                      : Text(
                                        '${StringUtils.formatDuration(seconds: position ?? 0)} / ${duration == null ? '--:--:--' : StringUtils.formatDuration(seconds: duration)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                ],
                              ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForMediaType() {
    if (widget.isActive) {
      return widget.controller.playerState.stateValue == StateValue.playing
          ? Icons.play_arrow_rounded
          : Icons.pause_rounded;
    }
    switch (widget.item.mediaItemType) {
      case MediaItemType.tvStream:
        return Icons.tv;
      case MediaItemType.audio:
        return Icons.audiotrack;
      case MediaItemType.video:
        return Icons.movie;
    }
  }
}

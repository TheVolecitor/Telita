import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sprintf/sprintf.dart';

import '../../../../../app_theme/app_theme.dart';

class ProgramTimelineWidget extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;

  const ProgramTimelineWidget({
    super.key,
    required this.startTime,
    required this.endTime,
  });

  @override
  State<ProgramTimelineWidget> createState() => _ProgramTimelineWidgetState();
}

class _ProgramTimelineWidgetState extends State<ProgramTimelineWidget> {
  Timer? _timer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _updateProgress();

    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _updateProgress();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateProgress() {
    final now = DateTime.now();
    if (now.isBefore(widget.startTime) || now.isAfter(widget.endTime)) {
      setState(() => _progress = 0.0);
      _timer?.cancel();
      return;
    }
    setState(() {
      _progress = (now.difference(widget.startTime).inSeconds /
              widget.endTime.difference(widget.startTime).inSeconds)
          .clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = widget.endTime.difference(now);
    final remainingText =
        remaining.isNegative
            ? OverlayLocalizations.get('programCompleted')
            : sprintf(OverlayLocalizations.get('programRemaining'), [
              remaining.inMinutes,
            ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.startTime.hour}:${widget.startTime.minute.toString().padLeft(2, '0')}',
              style: AppTheme.timelineTimeStyle,
            ),
            Text(remainingText, style: AppTheme.timelineTimeStyle),
            Text(
              '${widget.endTime.hour}:${widget.endTime.minute.toString().padLeft(2, '0')}',
              style: AppTheme.timelineTimeStyle,
            ),
          ],
        ),
        LinearProgressIndicator(
          value: _progress,
          minHeight: 6,
          borderRadius: AppTheme.borderRadius,
          color: AppTheme.fullFocusColor,
          backgroundColor: AppTheme.divider,
        ),
      ],
    );
  }
}

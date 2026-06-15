import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'dart:async';
import 'package:flutter_tv_media3/src/utils/string_utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app_theme/app_theme.dart';
import '../../../entity/clock_settings.dart';
import '../../bloc/overlay_ui_bloc.dart';
import '../../media_ui_service/media3_ui_controller.dart';

class ClockPanel extends StatelessWidget {
  final Media3UiController controller;
  const ClockPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OverlayUiBloc, OverlayUiState>(
      buildWhen:
          (oldState, newState) =>
              oldState.clockPosition != newState.clockPosition,
      builder: (context, state) {
        final clockPosition = state.clockPosition;
        if (clockPosition == ClockPosition.none) {
          return const SizedBox.shrink();
        }

        return Positioned(
          right: clockPosition.right,
          left: clockPosition.left,
          top: clockPosition.top,
          bottom: clockPosition.bottom,
          child: _ClockContainer(controller: controller),
        );
      },
    );
  }
}

class _ClockContainer extends StatelessWidget {
  final Media3UiController controller;
  const _ClockContainer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OverlayUiBloc, OverlayUiState>(
      buildWhen:
          (oldState, newState) =>
              oldState.clockSettings != newState.clockSettings,
      builder: (context, state) {
        return Material(
          color: Colors.transparent,
          child: IntrinsicWidth(
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 1.0,
                horizontal: 8.0,
              ),
              decoration: BoxDecoration(
                color:
                    state.clockSettings.showClockBackground
                        ? state.clockSettings.backgroundColor.color
                        : null,
                border:
                    state.clockSettings.showClockBorder
                        ? Border.all(
                          color: state.clockSettings.borderColor.color,
                        )
                        : null,
                borderRadius: AppTheme.borderRadius,
              ),
              child: _ClockContent(controller: controller),
            ),
          ),
        );
      },
    );
  }
}

class _ClockContent extends StatefulWidget {
  final Media3UiController controller;
  const _ClockContent({required this.controller});

  @override
  State<_ClockContent> createState() => _ClockContentState();
}

class _ClockContentState extends State<_ClockContent> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OverlayUiBloc, OverlayUiState>(
      buildWhen:
          (oldState, newState) =>
              oldState.sleepTime != newState.sleepTime ||
              oldState.sleepAfter != newState.sleepAfter ||
              oldState.clockSettings.clockColor !=
                  newState.clockSettings.clockColor,
      builder: (context, state) {
        final percentage = StringUtils.getPercentage(
          position: widget.controller.playbackState.position,
          duration: widget.controller.playbackState.duration,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Text(
              OverlayLocalizations.timeFormat(date: DateTime.now()),
              style: TextStyle(
                color: state.clockSettings.clockColor.color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            LinearProgressIndicator(
              value:
                  widget.controller.playerState.isLive == true ? 1 : percentage,
              color: AppTheme.fullFocusColor,
              backgroundColor: Colors.white60,
              minHeight: 3,
            ),
            _TimerIndicator(
              state: state,
              controller: widget.controller,
              percentage: percentage,
            ),
          ],
        );
      },
    );
  }
}

class _TimerIndicator extends StatelessWidget {
  final OverlayUiState state;
  final Media3UiController controller;
  final double percentage;

  const _TimerIndicator({
    required this.state,
    required this.controller,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    if (state.sleepAfter) {
      final isEnding = state.sleepAfterNext == false && percentage > 0.98;
      return _TimerInfoRow(
        text: OverlayLocalizations.get('sleepTimerAfterFile'),
        color:
            isEnding
                ? AppTheme.timeWarningColor
                : Colors.white.withValues(alpha: 0.9),
        isSmallText: true,
      );
    }
    if (state.sleepTime != Duration.zero) {
      final isEnding = state.sleepTime < const Duration(minutes: 4);
      return _TimerInfoRow(
        text: state.sleepTime.toString().durationClear(),
        color:
            isEnding
                ? AppTheme.timeWarningColor
                : Colors.white.withValues(alpha: 0.9),
      );
    }
    if (controller.playerState.isLive == true) {
      return Text(
        OverlayLocalizations.get('live'),
        style: TextStyle(
          color: state.clockSettings.clockColor.color,
          fontSize: 12,
        ),
      );
    }
    return Text(
      StringUtils.getTimeLeft(
        position: controller.playbackState.position,
        duration: controller.playbackState.duration,
        seconds: false,
      ),
      style: TextStyle(
        color: state.clockSettings.clockColor.color,
        fontSize: 12,
      ),
    );
  }
}

class _TimerInfoRow extends StatelessWidget {
  final String text;
  final Color color;
  final bool isSmallText;

  const _TimerInfoRow({
    required this.text,
    required this.color,
    this.isSmallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 4,
        children: [
          Icon(Icons.access_time_filled_outlined, size: 14, color: color),
          Text(
            text,
            style:
                isSmallText
                    ? Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: color, fontSize: 10)
                    : Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
          ),
        ],
      ),
    );
  }
}

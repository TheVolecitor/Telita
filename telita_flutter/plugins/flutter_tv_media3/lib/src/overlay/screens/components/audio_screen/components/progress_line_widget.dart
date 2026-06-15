import 'package:flutter/material.dart';

import '../../../../../app_theme/app_theme.dart';
import '../../../../../utils/string_utils.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';

class ProgressLineWidget extends StatelessWidget {
  const ProgressLineWidget({super.key, required this.controller});

  final Media3UiController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder(
      stream: controller.playbackStateStream,
      initialData: controller.playbackState,
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.hasData == false) return SizedBox.shrink();
        final data = asyncSnapshot.data!;
        final currentPosition = data.position;
        final currentDuration = data.duration;
        final positionPercentage = StringUtils.getPercentage(
          duration: data.duration,
          position: data.position,
        );
        final bufferedPercentage = StringUtils.getPercentage(
          duration: data.duration,
          position: data.bufferedPosition,
        );
        return Row(
          spacing: 6,
          children: [
            if (controller.playerState.isLive != true)
              Text(
                StringUtils.formatDuration(seconds: currentPosition),
                style: theme.textTheme.bodyMedium,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(color: Colors.white, height: 10),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 500),
                        color: Colors.grey,
                        height: 10,
                        width: constraints.maxWidth * bufferedPercentage,
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 500),
                        color: AppTheme.fullFocusColor,
                        height: 10,
                        width: constraints.maxWidth * positionPercentage,
                      ),
                    ],
                  );
                },
              ),
            ),
            if (controller.playerState.isLive != true)
              Text(
                StringUtils.formatDuration(seconds: currentDuration),
                style: theme.textTheme.bodyMedium,
              ),
          ],
        );
      },
    );
  }
}

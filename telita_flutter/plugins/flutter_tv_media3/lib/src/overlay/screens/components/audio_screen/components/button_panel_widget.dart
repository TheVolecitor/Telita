import 'package:flutter/material.dart';

import '../../../../../../flutter_tv_media3.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';

class ButtonPanelWidget extends StatelessWidget {
  const ButtonPanelWidget({
    super.key,
    required this.controller,
    required this.playIndex,
  });

  final Media3UiController controller;
  final int playIndex;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: controller.playerStateStream,
      initialData: controller.playerState,
      builder: (context, asyncSnapshot) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 32,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              iconSize: 34,
              onPressed: playIndex > 0 ? () {} : null,
            ),
            IconButton(
              icon: Icon(
                asyncSnapshot.data?.stateValue == StateValue.playing
                    ? Icons.play_arrow
                    : Icons.pause,
              ),
              iconSize: 66,
              onPressed: controller.playPause,
              color: Colors.white,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              iconSize: 34,
              onPressed:
                  controller.playerState.playlist.length - 1 > playIndex
                      ? () {}
                      : null,
            ),
          ],
        );
      },
    );
  }
}

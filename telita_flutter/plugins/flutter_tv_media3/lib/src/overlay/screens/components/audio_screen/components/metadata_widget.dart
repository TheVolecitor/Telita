import 'package:flutter/material.dart';

import '../../../../media_ui_service/media3_ui_controller.dart';

class MetaDataWidget extends StatelessWidget {
  const MetaDataWidget({super.key, required this.controller});

  final Media3UiController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme.headlineMedium;
    return StreamBuilder(
      stream: controller.mediaMetadataStream,
      initialData: controller.currentMetadata,
      builder: (context, asyncSnapshot) {
        return Column(
          children: [
            if (asyncSnapshot.data?.streamingMetadata?.icyTitle != null)
              Text(
                asyncSnapshot.data!.streamingMetadata!.icyTitle!,
                style: theme,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

            if (asyncSnapshot.data?.streamingMetadata?.id3Title != null)
              Text(
                asyncSnapshot.data!.streamingMetadata!.id3Title!,
                style: theme,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            if (asyncSnapshot.data?.streamingMetadata?.id3Artist != null)
              Text(
                asyncSnapshot.data!.streamingMetadata!.id3Artist!,
                style: theme,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            if (asyncSnapshot.data?.streamingMetadata?.id3Album != null)
              Text(
                asyncSnapshot.data!.streamingMetadata!.id3Album!,
                style: theme,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../../flutter_tv_media3.dart';
import '../../../../media_ui_service/media3_ui_controller.dart';

class TrackInfoWidget extends StatelessWidget {
  const TrackInfoWidget({
    super.key,
    required this.controller,
    required this.playItem,
  });
  final Media3UiController controller;
  final PlaylistMediaItem playItem;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String artistName =
        playItem.artistName ??
        controller.currentMetadata.artist ??
        playItem.title ??
        '';
    final String trackName =
        playItem.trackName ??
        controller.currentMetadata.title ??
        playItem.subTitle ??
        '';
    final String albumName =
        playItem.albumName ?? controller.currentMetadata.albumTitle ?? '';
    final String albumYear =
        playItem.albumYear ?? controller.currentMetadata.year?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trackName.isNotEmpty)
          Text(
            trackName,
            style: theme.textTheme.headlineMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (artistName.isNotEmpty)
          Text(
            artistName,
            style: theme.textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (albumName.isNotEmpty)
          Text(
            albumName,
            style: theme.textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (albumYear.isNotEmpty)
          Text(
            albumYear,
            style: theme.textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (trackName.isEmpty &&
            artistName.isEmpty &&
            albumName.isEmpty &&
            (playItem.label ?? '').isNotEmpty)
          Text(
            playItem.label ?? '',
            style: theme.textTheme.titleLarge,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

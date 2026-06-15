import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/overlay_ui_bloc.dart';
import '../../../media_ui_service/media3_ui_controller.dart';
import 'components/background_widget.dart';
import 'components/button_panel_widget.dart';
import 'components/info_string_widget.dart';
import 'components/metadata_widget.dart';
import 'components/progress_line_widget.dart';
import 'components/track_cover_widget.dart';
import 'components/track_info_widget.dart';

class AudioPlayerTVScreen extends StatelessWidget {
  final Media3UiController controller;

  const AudioPlayerTVScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<OverlayUiBloc, OverlayUiState>(
        buildWhen:
            (oldState, newState) => oldState.playIndex != newState.playIndex,
        builder: (context, state) {
          final playItem = controller.playerState.playlist[state.playIndex];

          final String? albumArtUrl =
              playItem.coverImg ?? controller.currentMetadata.artworkUri;
          final artworkData = controller.currentMetadata.artworkData;
          final image =
              albumArtUrl != null
                  ? DecorationImage(
                    image: NetworkImage(albumArtUrl),
                    fit: BoxFit.cover,
                  )
                  : artworkData != null
                  ? DecorationImage(image: MemoryImage(artworkData))
                  : null;

          return Stack(
            fit: StackFit.expand,
            children: [
              BackgroundWidget(
                placeholderImg: playItem.placeholderImg,
                artworkUrl: albumArtUrl,
                artworkData: artworkData,
              ),
              Padding(
                padding: const EdgeInsets.all(84.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 64,
                  children: [
                    Column(
                      children: [
                        TrackCoverWidget(image: image),
                        ButtonPanelWidget(
                          controller: controller,
                          playIndex: state.playIndex,
                        ),
                      ],
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          TrackInfoWidget(
                            controller: controller,
                            playItem: playItem,
                          ),
                          MetaDataWidget(controller: controller),
                          Spacer(),
                          ProgressLineWidget(controller: controller),
                          InfoStringWidget(controller: controller),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

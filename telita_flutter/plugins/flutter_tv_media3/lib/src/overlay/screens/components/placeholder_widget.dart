import 'package:flutter/material.dart';
import '../../../../flutter_tv_media3.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'widgets/custom_info_text_widget.dart';
import 'widgets/player_error_widget.dart';
import 'widgets/brand_loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class PlaceholderWidget extends StatefulWidget {
  const PlaceholderWidget({super.key, required this.controller});
  final Media3UiController controller;

  @override
  State<PlaceholderWidget> createState() => _PlaceholderWidgetState();
}

class _PlaceholderWidgetState extends State<PlaceholderWidget> {
  PlaylistMediaItem? _lastValidItem;

  @override
  void initState() {
    super.initState();
    // Prime the last valid item with the initial data from the controller.
    // This handles the case where the first video is launched.
    final playerState = widget.controller.playerState;
    final initialItem =
        playerState.playIndex != -1 && playerState.playlist.isNotEmpty
            ? playerState.playlist[playerState.playIndex]
            : null;
    if (initialItem?.title != null) {
      _lastValidItem = initialItem;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: StreamBuilder<PlayerState>(
        initialData: widget.controller.playerState,
        stream: widget.controller.playerStateStream,
        builder: (context, snapshot) {
          final playerState = snapshot.data;

          if (playerState == null) {
            return const Center(child: BrandLoadingIndicator(size: 60));
          }

          final currentItem =
              playerState.playIndex != -1 && playerState.playlist.isNotEmpty
                  ? playerState.playlist[playerState.playIndex]
                  : null;

          // Update last valid item only when we get a new item with a title.
          // This prevents showing an empty item during transition.
          if (currentItem?.title != null) {
            _lastValidItem = currentItem;
          }

          final itemToDisplay = _lastValidItem ?? currentItem;

          // Show error if item is invalid, regardless of activity state
          if (itemToDisplay == null) {
            return PlayerErrorWidget(
              lastError: OverlayLocalizations.get('playbackError'),
              errorCode: OverlayLocalizations.get('playlistIndexError'),
              onExit: widget.controller.stop,
              onRetry: () {
                final idx = widget.controller.playerState.playIndex;
                if (idx >= 0 && idx < widget.controller.playerState.playlist.length) {
                   widget.controller.playSelectedIndex(index: idx);
                }
              },
              onSwitchToVLC: () async {
                final idx = widget.controller.playerState.playIndex;
                if (idx >= 0 && idx < widget.controller.playerState.playlist.length) {
                  final uri = widget.controller.playerState.playlist[idx].url;
                  if (uri != null) {
                    final vlcUrl = uri.replaceFirst('http://', 'vlc://').replaceFirst('https://', 'vlc://');
                    try {
                      if (!await launchUrl(Uri.parse(vlcUrl))) {
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VLC is not installed.')));
                         }
                      }
                    } catch (e) {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VLC is not installed.')));
                       }
                    }
                  }
                }
              },
            );
          }

          if (itemToDisplay.coverImg != null) {
            precacheImage(
              NetworkImage(itemToDisplay.coverImg!),
              context,
              onError: (exception, stackTrace) {},
            );
          }

          final bool showLoadingIndicator =
              !playerState.activityReady ||
              playerState.stateValue == StateValue.buffering ||
              playerState.stateValue == StateValue.initial;

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(color: Colors.transparent),

              if (playerState.lastError != null)
                PlayerErrorWidget(
                  lastError: playerState.lastError!,
                  errorCode: playerState.errorCode,
                  onExit: () => widget.controller.stop(),
                  onRetry: () {
                    final idx = widget.controller.playerState.playIndex;
                    if (idx >= 0 && idx < widget.controller.playerState.playlist.length) {
                       widget.controller.playSelectedIndex(index: idx);
                    }
                  },
                  onSwitchToVLC: () async {
                    final idx = widget.controller.playerState.playIndex;
                    if (idx >= 0 && idx < widget.controller.playerState.playlist.length) {
                      final uri = widget.controller.playerState.playlist[idx].url;
                      if (uri != null) {
                        final vlcUrl = uri.replaceFirst('http://', 'vlc://').replaceFirst('https://', 'vlc://');
                        try {
                          if (!await launchUrl(Uri.parse(vlcUrl))) {
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VLC is not installed.')));
                             }
                          }
                        } catch (e) {
                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VLC is not installed.')));
                           }
                        }
                      }
                    }
                  },
                ),

              if (playerState.lastError == null)
                Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: const BrandLoadingIndicator(size: 60),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final PlaylistMediaItem? item;

  const _Content({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: item != null ? 1.0 : 0.0,
            child: Column(
              children: [
                if (item?.title != null)
                  Text(
                    item!.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                const SizedBox(height: 8),
                if (item?.subTitle != null && item?.title != item?.subTitle)
                  Text(
                    item!.subTitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                if (item?.label != null && item?.title != item?.label)
                  Text(
                    item!.label!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                const CustomInfoTextWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  final String imageUrl;

  const _BackgroundImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 64),
        );
      },
    );
  }
}


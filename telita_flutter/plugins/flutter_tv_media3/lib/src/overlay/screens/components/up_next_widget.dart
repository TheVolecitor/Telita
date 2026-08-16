import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../entity/playback_state.dart';
import '../../media_ui_service/media3_ui_controller.dart';

class UpNextWidget extends StatefulWidget {
  final Media3UiController controller;
  const UpNextWidget({super.key, required this.controller});

  @override
  State<UpNextWidget> createState() => _UpNextWidgetState();
}

class _UpNextWidgetState extends State<UpNextWidget> {
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

        final playItem = playlist[playerState.playIndex];
        if (!playItem.hasNextEpisode) return const SizedBox.shrink();

        final currentSecs = playback.position;
        final remaining = playback.duration - currentSecs;
        
        // Show in the final 10 seconds
        if (remaining > 10 || remaining < 0) return const SizedBox.shrink();

        final percentage = remaining / 10.0; // 1.0 down to 0.0

        final seasonStr = playItem.nextEpisodeSeason?.toString();
        final epStr = playItem.nextEpisodeNumber?.toString();
        String sxe = "";
        if (seasonStr != null && epStr != null) {
          sxe = "S${seasonStr}E${epStr}";
        }

        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120.0, right: 32.0),
            child: Focus(
              onFocusChange: (focused) => setState(() => _isFocused = focused),
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && 
                   (event.logicalKey == LogicalKeyboardKey.select || 
                    event.logicalKey == LogicalKeyboardKey.enter || 
                    event.logicalKey == LogicalKeyboardKey.space)) {
                  playItem.onNextEpisode?.call();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: InkWell(
                onTap: () {
                  playItem.onNextEpisode?.call();
                },
                child: Container(
                  width: 320,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isFocused ? Colors.white : Colors.white24,
                      width: _isFocused ? 3 : 1,
                    ),
                    boxShadow: _isFocused
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
                          ]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        // Background image
                        if (playItem.nextEpisodeThumbnail != null && playItem.nextEpisodeThumbnail!.isNotEmpty)
                          Positioned.fill(
                            child: Image.network(
                              playItem.nextEpisodeThumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        // Dark gradient overlay to make text readable
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.4),
                                  Colors.black.withOpacity(0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.skip_next, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'UP NEXT',
                                    style: TextStyle(
                                      color: Colors.white70, 
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (sxe.isNotEmpty)
                                Text(
                                  sxe,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              if (playItem.nextEpisodeTitle != null)
                                Text(
                                  playItem.nextEpisodeTitle!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4), // Space for progress bar
                            ],
                          ),
                        ),
                        // Progress bar at the bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 4,
                          child: LinearProgressIndicator(
                            value: 1.0 - percentage,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        // Countdown text
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              remaining.ceil().toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

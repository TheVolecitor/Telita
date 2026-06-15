import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import 'package:flutter_tv_media3/src/overlay/bloc/overlay_ui_bloc.dart';
import 'package:flutter_tv_media3/src/overlay/media_ui_service/media3_ui_controller.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_tv_media3/src/overlay/screens/components/widgets/marquee_title_widget.dart';

class HorizontalPlaylistPanel extends StatefulWidget {
  final Media3UiController controller;
  final Map<ShortcutActivator, VoidCallback> generalBindings;

  const HorizontalPlaylistPanel({
    super.key,
    required this.controller,
    required this.generalBindings,
  });

  @override
  State<HorizontalPlaylistPanel> createState() =>
      _HorizontalPlaylistPanelState();
}

class _HorizontalPlaylistPanelState extends State<HorizontalPlaylistPanel> {
  late ScrollController _scrollController;
  late int _selectedIndex;
  final FocusNode _focusNode = FocusNode();
  static const double _itemWidth = 260.0;
  static const double _itemHeight = 146.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectedIndex = context.read<OverlayUiBloc>().state.playIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToIndex(_selectedIndex);
      }
    });
  }

  @override
  void didUpdateWidget(HorizontalPlaylistPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPlayIndex = widget.controller.playerState.playIndex;
    if (newPlayIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = newPlayIndex;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToIndex(_selectedIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        widget.controller.playerState.playlist.isEmpty ||
        index < 0 ||
        index >= widget.controller.playerState.playlist.length) {
      return;
    }

    final viewportWidth = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;

    double targetOffset =
        (index * (_itemWidth + 24)) - (viewportWidth / 2) + (_itemWidth / 2);
    targetOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleKeyEvent(Function action) {
    setState(() {
      action();
    });

    final settings = widget.controller.playerState.playerSettings;
    if (settings.paginationEnable &&
        widget.controller.playerState.playlist.length - _selectedIndex <=
            settings.paginationThreshold) {
      widget.controller.onLoadMoreCalled();
    }
  }

  Map<ShortcutActivator, VoidCallback> _getShortcuts(
    List<PlaylistMediaItem> playlist,
  ) {
    final bindings = Map<ShortcutActivator, VoidCallback>.from(
      widget.generalBindings,
    );

    bindings.addAll({
      const SingleActivator(LogicalKeyboardKey.arrowLeft):
          () => _handleKeyEvent(() {
            if (playlist.isNotEmpty) {
              _selectedIndex =
                  (_selectedIndex - 1 + playlist.length) % playlist.length;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.arrowRight):
          () => _handleKeyEvent(() {
            if (playlist.isNotEmpty) {
              _selectedIndex = (_selectedIndex + 1) % playlist.length;
              _scrollToIndex(_selectedIndex);
            }
          }),
      const SingleActivator(LogicalKeyboardKey.enter):
          () => _handleKeyEvent(() async {
            if (_selectedIndex < playlist.length) {
              final bloc = context.read<OverlayUiBloc>();
              await widget.controller.playSelectedIndex(index: _selectedIndex);
              if (!mounted) return;
              bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
            }
          }),
      const SingleActivator(LogicalKeyboardKey.select):
          () => _handleKeyEvent(() async {
            if (_selectedIndex < playlist.length) {
              final bloc = context.read<OverlayUiBloc>();
              await widget.controller.playSelectedIndex(index: _selectedIndex);
              if (!mounted) return;
              bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
            }
          }),
      const SingleActivator(LogicalKeyboardKey.space):
          () => _handleKeyEvent(() async {
            if (_selectedIndex < playlist.length) {
              final bloc = context.read<OverlayUiBloc>();
              await widget.controller.playSelectedIndex(index: _selectedIndex);
              if (!mounted) return;
              bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
            }
          }),
      // Pressing down again should close and play previous as requested
      const SingleActivator(LogicalKeyboardKey.arrowDown): () {
        final bloc = context.read<OverlayUiBloc>();
        bloc.add(const SetActivePanel(playerPanel: PlayerPanel.none));
        widget.controller.playPrevious();
      },
      // Arrow up closes the panel
      const SingleActivator(LogicalKeyboardKey.arrowUp): () {
        context.read<OverlayUiBloc>().add(
          const SetActivePanel(playerPanel: PlayerPanel.none),
        );
      },
    });
    return bindings;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: _itemHeight + 140,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.98),
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
          child: StreamBuilder<PlayerState>(
            stream: widget.controller.playerStateStream,
            initialData: widget.controller.playerState,
            builder: (context, snapshot) {
              final playerState =
                  snapshot.data ?? widget.controller.playerState;
              final playlist = playerState.playlist;

              return CallbackShortcuts(
                bindings: _getShortcuts(playlist),
                child: Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 32.0,
                          top: 20.0,
                          right: 32.0,
                          bottom: 8.0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final currentPlayIndex =
                                      playerState.playIndex;
                                  final playItem =
                                      currentPlayIndex >= 0 &&
                                              currentPlayIndex < playlist.length
                                          ? playlist[currentPlayIndex]
                                          : null;

                                  if (playItem == null) {
                                    return Text(
                                      OverlayLocalizations.get('playlist'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          const Shadow(
                                            color: Colors.black,
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }

                                  return Text(
                                    playItem.title ?? playItem.label!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        const Shadow(
                                          color: Colors.black,
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${playerState.playIndex + 1} / ${playlist.length}",
                                style: TextStyle(
                                  color: AppTheme.backgroundColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Scrollbar(
                            controller: _scrollController,
                            child: ListView.builder(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 12.0,
                              ),
                              itemCount: playlist.length,
                              itemBuilder: (context, index) {
                                final item = playlist[index];
                                final isSelected = index == _selectedIndex;
                                final isActive = index == playerState.playIndex;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                  ),
                                  child: HorizontalPlaylistItem(
                                    item: item,
                                    index: index,
                                    isSelected: isSelected,
                                    isActive: isActive,
                                    onTap: () {
                                      widget.controller.playSelectedIndex(
                                        index: index,
                                      );
                                      context.read<OverlayUiBloc>().add(
                                        const SetActivePanel(
                                          playerPanel: PlayerPanel.none,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class HorizontalPlaylistItem extends StatelessWidget {
  final PlaylistMediaItem item;
  final int index;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;

  const HorizontalPlaylistItem({
    super.key,
    required this.item,
    required this.index,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected ? AppTheme.fullFocusColor : Colors.white12,
                      width: isSelected ? 3 : 1.5,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: AppTheme.fullFocusColor.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ]
                            : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      children: [
                        _PlaylistItemThumbnail(item: item, isActive: isActive),
                        if (isActive) const _PlaylistItemActiveIndicator(),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _ProgressBar(item: item),
                        ),
                        if (item.duration != null && item.duration! > 0)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.startPosition != null &&
                                        item.startPosition! > 0
                                    ? "${StringUtils.formatDuration(seconds: item.startPosition!)} / ${StringUtils.formatDuration(seconds: item.duration!)}"
                                    : StringUtils.formatDuration(
                                      seconds: item.duration!,
                                    ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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
            const SizedBox(height: 12),
            _PlaylistItemTitle(
              item: item,
              index: index,
              isSelected: isSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistItemThumbnail extends StatelessWidget {
  final PlaylistMediaItem item;

  final bool isActive;

  const _PlaylistItemThumbnail({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white10, Colors.white.withValues(alpha: 0.05)],
        ),
      ),
      child: Center(
        child: Icon(
          _getIconForMediaType(),
          size: 40,
          color: isActive ? AppTheme.fullFocusColor : Colors.white24,
        ),
      ),
    );

    final imageUrl = item.episodeImg ?? item.placeholderImg ?? item.coverImg;

    if (imageUrl == null) return placeholder;

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder:
          (context, child, progress) =>
              progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator(color: Colors.white70)),
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  IconData _getIconForMediaType() {
    return switch (item.mediaItemType) {
      MediaItemType.tvStream => Icons.live_tv_rounded,
      MediaItemType.audio => Icons.music_note_rounded,
      MediaItemType.video => Icons.play_circle_outline_rounded,
    };
  }
}

class _PlaylistItemActiveIndicator extends StatelessWidget {
  const _PlaylistItemActiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.fullFocusColor.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 1),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _PlaylistItemTitle extends StatelessWidget {
  final PlaylistMediaItem item;

  final int index;

  final bool isSelected;

  const _PlaylistItemTitle({
    required this.item,
    required this.index,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return MarqueeWidget(
      text:
          item.label ??
          item.title ??
          sprintf(OverlayLocalizations.get('itemNumber'), [index + 1]),
      focus: isSelected,
      style: TextStyle(
        color: isSelected ? Colors.white : Colors.white60,
        fontSize: 14,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final PlaylistMediaItem item;

  const _ProgressBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final duration = item.duration;
    final position = item.startPosition;

    if (position == null || duration == null || duration <= 0) {
      return const SizedBox.shrink();
    }

    final percent = (position / duration).clamp(0.0, 1.0);
    final isWatched = percent > 0.95;

    return LinearProgressIndicator(
      value: percent,
      minHeight: 6,
      backgroundColor: Colors.white54,
      valueColor: AlwaysStoppedAnimation<Color>(
        isWatched
            ? AppTheme.timeWarningColor
            : AppTheme.timeWarningColor.withValues(alpha: 0.8),
      ),
    );
  }
}


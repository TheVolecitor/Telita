import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';

import '../../bloc/overlay_ui_bloc.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'time_line_panel.dart';
import 'widgets/video_info_widget.dart';

class InfoPanel extends StatelessWidget {
  final Media3UiController controller;

  const InfoPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: BlocBuilder<OverlayUiBloc, OverlayUiState>(
            buildWhen:
                (oldState, newState) =>
                    oldState.playIndex != newState.playIndex ||
                    oldState.playerPanel != newState.playerPanel,
            builder: (context, state) {
              final playerState = controller.playerState;
              final playlist = playerState.playlist;

              if (playlist.isEmpty || state.playIndex >= playlist.length) {
                return const SizedBox.shrink();
              }

              final playItem = playlist[state.playIndex];
              final poster = playItem.coverImg ?? playItem.placeholderImg;
              final title = playItem.title ?? playItem.label ?? "";

              final hasEpg =
                  playItem.programs != null && playItem.programs!.isNotEmpty;
              final programs = playItem.programs ?? [];

              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  top: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntrinsicHeight(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (playItem.coverImg != null)
                              Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: AppTheme.borderRadius,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                constraints: const BoxConstraints(
                                  maxHeight: 170,
                                  minWidth: 120,
                                ),
                                child: Image.network(
                                  playItem.coverImg!,
                                  fit: BoxFit.cover,
                                  height: 170,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: const CircularProgressIndicator(color: Colors.white70),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.image,
                                        color: Colors.white38,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (poster != null) const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 4,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 8,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
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
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: AppTheme.borderRadius,
                                        ),
                                        child: Text(
                                          "${state.playIndex + 1} / ${playlist.length}",
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
                                  if (playItem.subTitle != null)
                                    Text(
                                      playItem.subTitle!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (playItem.label != null &&
                                      playItem.subTitle != playItem.label)
                                    Text(
                                      playItem.label!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Expanded(
                                    child:
                                        hasEpg
                                            ? _EpgInfo(programs: programs)
                                            : playItem.description != null
                                            ? Text(
                                              playItem.description!,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                                height: 1.4,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                            : const SizedBox.shrink(),
                                  ),
                                  VideoInfoWidget(
                                    controller: controller,
                                    state: state,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TimeLinePanel(controller: controller),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EpgInfo extends StatefulWidget {
  final List<EpgProgram> programs;
  const _EpgInfo({required this.programs});

  @override
  State<_EpgInfo> createState() => _EpgInfoState();
}

class _EpgInfoState extends State<_EpgInfo> {
  EpgProgram? _currentProgram;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateProgram();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateProgram();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateProgram() {
    final now = DateTime.now();
    try {
      final currentProgram = widget.programs.firstWhere(
        (program) =>
            now.isAfter(program.startTime) && now.isBefore(program.endTime),
      );
      if (currentProgram != _currentProgram) {
        setState(() {
          _currentProgram = currentProgram;
        });
      }
    } catch (_) {
      if (_currentProgram != null) {
        setState(() {
          _currentProgram = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentProgram == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final totalSeconds =
        _currentProgram!.endTime
            .difference(_currentProgram!.startTime)
            .inSeconds;
    final progress =
        totalSeconds > 0
            ? now.difference(_currentProgram!.startTime).inSeconds /
                totalSeconds
            : 0.0;

    final startTime = OverlayLocalizations.timeFormat(
      date: _currentProgram!.startTime,
    );
    final endTime = OverlayLocalizations.timeFormat(
      date: _currentProgram!.endTime,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _currentProgram!.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (_currentProgram!.description != null) ...[
          const SizedBox(height: 4),
          Text(
            _currentProgram!.description!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              startTime,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white24,
                color: Colors.white,
                minHeight: 4,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              endTime,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}


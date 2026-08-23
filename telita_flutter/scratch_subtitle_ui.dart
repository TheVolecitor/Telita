import 'package:flutter/material.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';

// We'll mock the missing dependencies for syntax checking
class _TvIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _TvIconButton({required this.icon, required this.tooltip, required this.onPressed});
  @override Widget build(BuildContext context) => const SizedBox();
}

String _getLanguageName(String raw) => raw; // mock

class SubtitleTrackSelector extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onActivity;
  final List<dynamic> externalSubtitles; // Mock dynamic for now
  final int activeExternalSubIndex;
  final Function(int index, String url) onSelectExternalSubtitle;
  final VoidCallback onDisableExternalSubtitle;

  const SubtitleTrackSelector({
    super.key,
    required this.controller,
    required this.onActivity,
    this.externalSubtitles = const [],
    this.activeExternalSubIndex = -1,
    required this.onSelectExternalSubtitle,
    required this.onDisableExternalSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Return icon button that shows the modal
    return const SizedBox();
  }
}

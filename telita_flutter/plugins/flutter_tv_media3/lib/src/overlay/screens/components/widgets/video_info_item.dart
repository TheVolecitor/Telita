import 'package:flutter/material.dart';

import '../../../../app_theme/app_theme.dart';

class VideoInfoItem extends StatelessWidget {
  const VideoInfoItem({super.key, required this.icon, this.title});

  final IconData icon;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: AppTheme.borderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          if (title != null) ...[Text(title!, style: AppTheme.infoTextStyle)],
        ],
      ),
    );
  }
}

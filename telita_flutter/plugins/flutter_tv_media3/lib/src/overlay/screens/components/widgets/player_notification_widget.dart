import 'package:flutter/material.dart';

enum NotificationType { success, error, info }

class PlayerNotificationWidget extends StatelessWidget {
  final String message;
  final NotificationType type;

  const PlayerNotificationWidget({
    super.key,
    required this.message,
    required this.type,
  });

  IconData get _iconData {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.info:
        return Icons.info_outline;
    }
  }

  Color get _color {
    switch (type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconData, color: _color, size: 28),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

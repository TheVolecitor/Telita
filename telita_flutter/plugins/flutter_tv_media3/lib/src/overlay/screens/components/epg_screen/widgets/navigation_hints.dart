import 'package:flutter/material.dart';

import '../../../../../app_theme/app_theme.dart';

class NavigationHints extends StatelessWidget {
  final bool showVertical;
  final bool canScrollUp;
  final bool canScrollDown;

  const NavigationHints({
    super.key,
    this.showVertical = false,
    this.canScrollUp = false,
    this.canScrollDown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_left, size: 20, color: AppTheme.colorPrimary),
              Icon(Icons.arrow_right, size: 20, color: AppTheme.colorPrimary),
            ],
          ),
          if (showVertical)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_drop_up,
                  size: 20,
                  color: canScrollUp ? AppTheme.colorPrimary : AppTheme.divider,
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color:
                      canScrollDown ? AppTheme.colorPrimary : AppTheme.divider,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

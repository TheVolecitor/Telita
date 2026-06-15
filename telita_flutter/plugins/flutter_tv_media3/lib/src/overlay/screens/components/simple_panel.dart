import 'package:flutter/material.dart';
import '../../../app_theme/app_theme.dart';
import '../../media_ui_service/media3_ui_controller.dart';
import 'time_line_panel.dart';

class SimplePanel extends StatelessWidget {
  final Media3UiController controller;
  const SimplePanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.only(left: 40, right: 40, bottom: 20, top: 60),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.9),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.0),
                ],
              ),
            ),
            child: TimeLinePanel(controller: controller),
          ),
        ),
      ],
    );
  }
}

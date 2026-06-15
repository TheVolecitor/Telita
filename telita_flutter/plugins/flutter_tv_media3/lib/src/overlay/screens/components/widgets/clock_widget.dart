import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';

class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key, this.style});
  final TextStyle? style;

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late Timer _timer;
  late TextStyle style;
  @override
  void initState() {
    style =
        widget.style ??
        const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        );
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      OverlayLocalizations.timeFormat(date: DateTime.now()),
      style: style,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../flutter_tv_media3.dart';
import 'bloc/overlay_ui_bloc.dart';
import 'media_ui_service/media3_ui_controller.dart';

@pragma('vm:entry-point')
void overlayEntryPoint() {
  try {
    runApp(const OverlayApp());
  } catch (_) {}
}

class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  late Media3UiController _controller;
  @override
  void initState() {
    super.initState();
    OverlayLocalizations.init();
    _controller = Media3UiController();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: BlocProvider(
        create: (context) => OverlayUiBloc(controller: _controller),
        child: OverlayScreen(controller: _controller),
      ),
    );
  }
}

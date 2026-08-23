import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// A minimal, standalone fullscreen video player for local files.
/// Uses the exact same VideoPlayerController.file approach as the working
/// fvp_test_app — no FtvMedia3PlayerController involvement at all.
class LocalFilePlayer extends StatefulWidget {
  final String filePath; // native OS path, e.g. C:\Videos\movie.mkv
  final String title;

  const LocalFilePlayer({
    Key? key,
    required this.filePath,
    required this.title,
  }) : super(key: key);

  @override
  State<LocalFilePlayer> createState() => _LocalFilePlayerState();
}

class _LocalFilePlayerState extends State<LocalFilePlayer> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isInitialized = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    _controller = controller;

    controller.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        controller.play();
        _scheduleHideControls();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
      print('[LOCAL-PLAYER] Init error: $e');
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _seekRelative(int seconds) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final newPos = ctrl.value.position + Duration(seconds: seconds);
    final clamped = newPos.isNegative ? Duration.zero : newPos;
    ctrl.seekTo(clamped);
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final initialized = _isInitialized && ctrl != null && ctrl.value.isInitialized;
    final isPlaying = ctrl?.value.isPlaying ?? false;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ?? Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Video
            Center(
              child: _errorMsg != null
                  ? _buildError()
                  : !initialized
                      ? const CircularProgressIndicator(color: Colors.white)
                      : AspectRatio(
                          aspectRatio: ctrl.value.aspectRatio,
                          child: VideoPlayer(ctrl),
                        ),
            ),

            // Controls overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xCC000000),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xCC000000),
                      ],
                      stops: [0, 0.2, 0.75, 1],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Center controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 40,
                              icon: const Icon(Icons.replay_10, color: Colors.white),
                              onPressed: () => _seekRelative(-10),
                            ),
                            const SizedBox(width: 32),
                            IconButton(
                              iconSize: 56,
                              icon: Icon(
                                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (isPlaying) {
                                  ctrl?.pause();
                                } else {
                                  ctrl?.play();
                                }
                                _scheduleHideControls();
                              },
                            ),
                            const SizedBox(width: 32),
                            IconButton(
                              iconSize: 40,
                              icon: const Icon(Icons.forward_10, color: Colors.white),
                              onPressed: () => _seekRelative(10),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Bottom seek bar + time
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: initialized && duration.inMilliseconds > 0
                                          ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble())
                                          : 0,
                                      min: 0,
                                      max: initialized && duration.inMilliseconds > 0
                                          ? duration.inMilliseconds.toDouble()
                                          : 1,
                                      activeColor: Colors.white,
                                      inactiveColor: Colors.white38,
                                      onChanged: initialized
                                          ? (val) {
                                              ctrl?.seekTo(Duration(milliseconds: val.toInt()));
                                              _scheduleHideControls();
                                            }
                                          : null,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(
          'Failed to open file:\n${widget.filePath}',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _errorMsg ?? '',
          style: const TextStyle(color: Colors.red, fontSize: 11),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Go Back'),
        ),
      ],
    );
  }
}

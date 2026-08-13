import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../../../flutter_tv_media3.dart';
import 'dart:io';
import '../../overlay/media_ui_service/media3_ui_controller.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../overlay/bloc/overlay_ui_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:fvp/fvp.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:lottie/lottie.dart';
import '../../overlay/screens/components/widgets/brand_loading_indicator.dart';

/// A screen widget launched from the main application to display the loading
/// process of the native player.
///
/// This screen acts as a temporary container or placeholder. Its primary role
/// is to show the user a loading indicator while the native player (running in
/// its own Android Activity) initializes in the background.
///
/// Once the native player is ready (signaled by `activityReady` in the
/// [PlayerState] stream), this screen automatically closes, and the user
/// sees the full player interface.
class Media3PlayerScreen extends StatefulWidget {
  const Media3PlayerScreen({
    super.key,
    this.playerLabel,
    required this.playlist,
    this.initialIndex = 0,
    this.placeholderWidget,
  });
  final List<PlaylistMediaItem> playlist;
  final int initialIndex;
  final Widget? playerLabel;
  final Widget? placeholderWidget;
  @override
  State<Media3PlayerScreen> createState() => _Media3PlayerScreenState();
}

class _Media3PlayerScreenState extends State<Media3PlayerScreen>
    with WidgetsBindingObserver {
  late final FtvMedia3PlayerController _controller;
  Media3UiController? _overlayController;
  bool isClose = false;
  bool _loadingTimedOut = false;
  Timer? _loadingTimeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = FtvMedia3PlayerController();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      _loadingTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && FtvMedia3PlayerController().videoPlayerController == null) {
          setState(() => _loadingTimedOut = true);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
      try {
        if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          _overlayController = Media3UiController();
          _overlayController!.initForWindows(widget.playlist, widget.initialIndex);
          setState(() {});
        }
        await _controller.openNativePlayer(
          playlist: widget.playlist,
          initialIndex: widget.initialIndex,
        );
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar(context, e.toString());
          if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
            setState(() => _loadingTimedOut = true);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _loadingTimeoutTimer?.cancel();
    _controller.closePlayer();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused && mounted && !isClose && !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      isClose = true;
      Navigator.of(context).maybePop();
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          spacing: 12,
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: AppTheme.errColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // On Windows, MPV renders its own full-screen overlay with the Lua OSD.
    // We just need a black background behind it while it loads.
    if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final controller = FtvMedia3PlayerController().videoPlayerController;
      if (controller == null) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: _loadingTimedOut
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Player failed to load',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'MPV did not initialize in time.',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('Go Back'),
                          ),
                        ],
                      )
                    : const BrandLoadingIndicator(size: 72, color: AppTheme.fullFocusColor),
              ),
              Positioned(
                top: 16,
                left: 8,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.black,
        body: _WindowsDesktopPlayer(
          controller: controller,
          playlist: widget.playlist,
          initialIndex: widget.initialIndex,
          onBack: () => Navigator.of(context).maybePop(),
          overlayController: _overlayController,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<PlayerState>(
        stream: _controller.playerStateStream,
        builder: (context, snapshot) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.placeholderWidget != null) widget.placeholderWidget!,
              Center(
                child:
                    widget.playerLabel ??
                    Text(
                      'FTVMedia3',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.merge(AppTheme.boldTextStyle),
                    ),
              ),
              Positioned(
                bottom: 50,
                left: 200,
                right: 200,
                child: Column(
                  children: [
                    Text(
                      OverlayLocalizations.get('loading'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.merge(
                        AppTheme.extraLightTextStyle,
                      ),
                    ),
                    LinearProgressIndicator(
                      color: AppTheme.fullFocusColor,
                      backgroundColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Windows-specific player: manual mouse/keyboard/cursor management so we are
// not dependent on media_kit's internal FocusNode behaviour.
// ---------------------------------------------------------------------------

class _WindowsDesktopPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final List<PlaylistMediaItem> playlist;
  final int initialIndex;
  final VoidCallback onBack;
  final Media3UiController? overlayController;

  const _WindowsDesktopPlayer({
    required this.controller,
    required this.playlist,
    required this.initialIndex,
    required this.onBack,
    this.overlayController,
  });

  @override
  State<_WindowsDesktopPlayer> createState() => _WindowsDesktopPlayerState();
}

class _WindowsDesktopPlayerState extends State<_WindowsDesktopPlayer> {
  bool _controlsVisible = true;
  bool _controlsMounted = true;
  Timer? _hideTimer;
  Timer? _unmountTimer;
  Timer? _historyTimer;
  static const _hideAfter = Duration(seconds: 3);
  SubtitleStyle? _subtitleStyle;
  StreamSubscription<PlayerState>? _styleSubscription;
  bool _isInitialized = false;
  bool _isFullscreen = false;
  bool _defaultAudioSelected = false;

  @override
  void initState() {
    super.initState();
    _isInitialized = widget.controller.value.isInitialized;
    widget.controller.addListener(_checkInit);
    _subtitleStyle = widget.overlayController?.playerState.subtitleStyle;
    _styleSubscription = widget.overlayController?.playerStateStream.listen((state) {
      if (mounted && state.subtitleStyle != _subtitleStyle) {
        setState(() => _subtitleStyle = state.subtitleStyle);
      }
    });
    _historyTimer = Timer.periodic(const Duration(seconds: 5), _syncWatchHistory);
  }

  void _syncWatchHistory([Timer? _]) {
    if (!mounted) return;
    final value = widget.controller.value;
    if (!value.isInitialized || value.duration == Duration.zero) return;

    final positionSec = value.position.inSeconds;
    final durationSec = value.duration.inSeconds;
    
    if (durationSec == 0 || positionSec <= 5) return;
    
    if (widget.initialIndex >= 0 && widget.initialIndex < widget.playlist.length) {
      final item = widget.playlist[widget.initialIndex];
      if (item.saveWatchTime != null) {
        item.saveWatchTime!(
          id: item.id,
          duration: durationSec,
          position: positionSec > durationSec ? durationSec : positionSec,
          playIndex: widget.initialIndex,
        );
      }
    }
  }

  void _checkInit() {
    if (mounted && widget.controller.value.isInitialized != _isInitialized) {
      setState(() => _isInitialized = widget.controller.value.isInitialized);

      if (_isInitialized && !_defaultAudioSelected) {
        _defaultAudioSelected = true;
        _selectDefaultAudioTrack();
      }
    }
  }

  // Waits briefly for fvp to finish parsing track metadata before
  // selecting English audio. Falls back to first track if not found.
  void _selectDefaultAudioTrack() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final mediaInfo = widget.controller.getMediaInfo();
      final audioTracks = mediaInfo?.audio ?? [];
      if (audioTracks.isEmpty) {
        // Still no tracks — just pick first
        try { widget.controller.setAudioTracks([0]); } catch (_) {}
        return;
      }

      try {
        int targetPosition = 0; // fallback to first track (0-based)
        for (int i = 0; i < audioTracks.length; i++) {
          final lang = audioTracks[i].metadata['language']?.toUpperCase() ?? '';
          final title = audioTracks[i].metadata['title']?.toUpperCase() ?? '';
          
          if (lang == 'ENG' || lang == 'EN' || lang == 'ENGLISH' || 
              title.contains('ENG') || title.contains('ENGLISH')) {
            targetPosition = i;
            break;
          }
        }
        widget.controller.setAudioTracks([targetPosition]);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _syncWatchHistory();
    widget.controller.removeListener(_checkInit);
    _hideTimer?.cancel();
    _unmountTimer?.cancel();
    _historyTimer?.cancel();
    _styleSubscription?.cancel();
    super.dispose();
  }

  void _onMouseActivity() {
    _hideTimer?.cancel();
    _unmountTimer?.cancel();
    if (!_controlsMounted || !_controlsVisible) {
      setState(() {
        _controlsMounted = true;
        _controlsVisible = true;
      });
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    if (!widget.controller.value.isPlaying) return; // keep visible when paused
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) {
        setState(() => _controlsVisible = false);
        _unmountTimer = Timer(const Duration(milliseconds: 250), () {
          if (mounted) setState(() => _controlsMounted = false);
        });
      }
    });
  }

  void _togglePlay() {
    widget.controller.value.isPlaying ? widget.controller.pause() : widget.controller.play();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      acrylic.Window.enterFullscreen();
    } else {
      acrylic.Window.exitFullscreen();
    }
  }

  void _seek(Duration delta) {
    final next = widget.controller.value.position + delta;
    widget.controller.seekTo(next.isNegative ? Duration.zero : next);
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    _onMouseActivity();
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _togglePlay();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _seek(const Duration(seconds: 10));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _seek(const Duration(seconds: -10));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        widget.controller.setVolume((widget.controller.value.volume + 0.05).clamp(0.0, 1.0));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        widget.controller.setVolume((widget.controller.value.volume - 0.05).clamp(0.0, 1.0));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onBack();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }



  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _controlsVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
      onHover: (_) => _onMouseActivity(),
      onEnter: (_) => _onMouseActivity(),
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video fills the entire space with no built-in controls overlay.
            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePlay,
                child: RepaintBoundary(
                  child: _isInitialized
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: widget.controller.value.aspectRatio,
                            child: VideoPlayer(widget.controller),
                          ),
                        )
                      : const Center(
                          child: BrandLoadingIndicator(size: 72, color: AppTheme.fullFocusColor),
                        ),
                ),
              ),
            ),

            // Error or Buffering indicator
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: widget.controller,
              builder: (context, value, child) {
                if (value.hasError) {
                  final item = widget.playlist.isNotEmpty && widget.initialIndex >= 0 && widget.initialIndex < widget.playlist.length
                      ? widget.playlist[widget.initialIndex]
                      : null;
                  return Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white54, size: 64),
                          const SizedBox(height: 24),
                          const Text(
                            'Playback Error',
                            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48.0),
                            child: Text(
                              value.errorDescription ?? 'Unknown error occurred.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54, fontSize: 15),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Exit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                ),
                                onPressed: widget.onBack,
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.fullFocusColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                ),
                                onPressed: () {
                                  // Can't easily restart a failed fvp instance from overlay
                                  // Exit and let the user click the item again.
                                  widget.onBack();
                                },
                              ),
                              if (item?.url != null && item!.url.isNotEmpty) ...[
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Open in VLC'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  ),
                                  onPressed: () {
                                    if (Platform.isWindows) {
                                      Process.start('cmd', ['/c', 'start', '', 'vlc', item.url]);
                                    } else {
                                      Process.start('vlc', [item.url]);
                                    }
                                  },
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.play_circle),
                                  label: const Text('Open in MPV'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  ),
                                  onPressed: () {
                                    if (Platform.isWindows) {
                                      Process.start('cmd', ['/c', 'start', '', 'mpv', item.url]);
                                    } else {
                                      Process.start('mpv', [item.url]);
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return value.isBuffering
                    ? const Center(
                        child: BrandLoadingIndicator(
                          size: 80,
                          color: AppTheme.fullFocusColor,
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),

            // Controls overlay — fades in/out on mouse activity.
            if (_controlsMounted)
              RepaintBoundary(
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _ControlsOverlay(
                    controller: widget.controller,
                    playlist: widget.playlist,
                    initialIndex: widget.initialIndex,
                    onBack: widget.onBack,
                    onActivity: _onMouseActivity,
                    isFullscreen: _isFullscreen,
                    onToggleFullscreen: _toggleFullscreen,
                  ),
                ),
              ),
            _WindowsSkipSegmentOverlay(
              controller: widget.controller,
              segments: widget.playlist.isNotEmpty && widget.initialIndex >= 0 && widget.initialIndex < widget.playlist.length
                  ? widget.playlist[widget.initialIndex].segments
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowsSkipSegmentOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final List<MediaSegment>? segments;

  const _WindowsSkipSegmentOverlay({
    required this.controller,
    required this.segments,
  });

  @override
  State<_WindowsSkipSegmentOverlay> createState() => _WindowsSkipSegmentOverlayState();
}

class _WindowsSkipSegmentOverlayState extends State<_WindowsSkipSegmentOverlay> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    if (widget.segments == null || widget.segments!.isEmpty) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        if (!value.isInitialized || value.duration == Duration.zero) {
          return const SizedBox.shrink();
        }

        final currentSecs = value.position.inSeconds;
        MediaSegment? active;
        for (final seg in widget.segments!) {
          final start = seg.startSec ?? 0;
          if (currentSecs >= start && currentSecs < seg.endSec) {
            active = seg;
            break;
          }
        }

        if (active == null) {
          return const SizedBox.shrink();
        }

        final label = active.type.toLowerCase() == 'intro'
            ? 'Skip Intro'
            : active.type.toLowerCase() == 'recap'
                ? 'Skip Recap'
                : active.type.toLowerCase() == 'credits'
                    ? 'Skip Credits'
                    : 'Skip ${active.type}';

        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 110.0, right: 32.0),
            child: Focus(
              onFocusChange: (focused) => setState(() => _isFocused = focused),
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.select ||
                     event.logicalKey == LogicalKeyboardKey.enter ||
                     event.logicalKey == LogicalKeyboardKey.space)) {
                  widget.controller.seekTo(Duration(seconds: active!.endSec));
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: InkWell(
                onTap: () {
                  widget.controller.seekTo(Duration(seconds: active!.endSec));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isFocused ? AppTheme.fullFocusColor : Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isFocused ? Colors.white : Colors.white30,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: _isFocused ? Colors.black : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.skip_next,
                        color: _isFocused ? Colors.black : Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final List<PlaylistMediaItem> playlist;
  final int initialIndex;
  final VoidCallback onBack;
  final VoidCallback onActivity;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  const _ControlsOverlay({
    super.key,
    required this.controller,
    required this.playlist,
    required this.initialIndex,
    required this.onBack,
    required this.onActivity,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient scrim at top and bottom.
        Positioned.fill(
          child: Column(
            children: [
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Top bar: back button.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBack,
                ),
              ],
            ),
          ),
        ),

        // Bottom bar: play/pause, seek, position, volume, extras.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SeekBar(controller: controller, onActivity: onActivity),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Play / pause
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, val, _) {
                          final playing = val.isPlaying;
                          return IconButton(
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              onActivity();
                              playing ? controller.pause() : controller.play();
                            },
                          );
                        },
                      ),
                      // Position / duration
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, val, _) {
                          return Text(
                            '${_fmt(val.position)} / ${_fmt(val.duration)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          );
                        },
                      ),
                      const Spacer(),
                      SubtitleTrackSelector(controller: controller, onActivity: onActivity),
                      AudioTrackSelector(controller: controller, onActivity: onActivity),
                      // Volume
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, val, _) {
                          final vol = val.volume;
                          return IconButton(
                            icon: Icon(
                              vol == 0
                                  ? Icons.volume_off
                                  : vol < 0.5
                                      ? Icons.volume_down
                                      : Icons.volume_up,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              onActivity();
                              controller.setVolume(vol > 0 ? 0 : 1.0);
                            },
                          );
                        },
                      ),

                      FullscreenButton(
                        onActivity: onActivity,
                        isFullscreen: isFullscreen,
                        onToggle: onToggleFullscreen,
                      ),
                      PlayerMoreMenuButton(
                        controller: controller,
                        playlist: playlist,
                        initialIndex: initialIndex,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _SeekBar extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onActivity;
  const _SeekBar({super.key, required this.controller, required this.onActivity});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, val, _) {
        final pos = val.position.inMilliseconds.toDouble();
        final dur = val.duration.inMilliseconds.toDouble();
        final total = dur;
        final current = (_dragging ?? pos).clamp(0.0, total > 0 ? total : 1.0);

        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.fullFocusColor,
            thumbColor: AppTheme.fullFocusColor,
            inactiveTrackColor: Colors.white24,
            overlayColor: AppTheme.fullFocusColor.withOpacity(0.2),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            min: 0,
            max: total > 0 ? total : 1.0,
            value: current,
            onChangeStart: (_) => widget.onActivity(),
            onChanged: (v) {
              widget.onActivity();
              setState(() => _dragging = v);
            },
            onChangeEnd: (v) {
              widget.controller.seekTo(Duration(milliseconds: v.round()));
              setState(() => _dragging = null);
            },
          ),
        );
      },
    );
  }
}

void showTrackSelectionDialog<T>({

  required BuildContext context,
  required String title,
  required List<T> tracks,
  required T activeTrack,
  required String Function(T) getTrackLabel,
  required List<String> Function(T) getTrackBadges,
  required void Function(T) onTrackSelected,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12, width: 1),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 380,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isSelected = track == activeTrack;
              final badges = getTrackBadges(track);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.fullFocusColor.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppTheme.fullFocusColor : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          getTrackLabel(track),
                          style: TextStyle(
                            color: isSelected ? AppTheme.fullFocusColor : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      ...badges.map((badgeText) => Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppTheme.fullFocusColor.withOpacity(0.2) 
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected 
                                ? AppTheme.fullFocusColor.withOpacity(0.5) 
                                : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: isSelected ? AppTheme.fullFocusColor : Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )),
                    ],
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.fullFocusColor) : null,
                  onTap: () {
                    onTrackSelected(track);
                    Navigator.of(context).pop();
                  },
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class SubtitleTrackButton extends StatelessWidget {
  const SubtitleTrackButton({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class AudioTrackButton extends StatelessWidget {
  const AudioTrackButton({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class PlayerMoreMenuButton extends StatelessWidget {
  final VideoPlayerController controller;
  final List<PlaylistMediaItem> playlist;
  final int initialIndex;

  const PlayerMoreMenuButton({
    required this.controller,
    required this.playlist,
    required this.initialIndex,
    super.key,
  });

  String _getStreamUrl() {
    if (playlist.isEmpty) return '';
    return playlist[initialIndex].originalUrl ?? playlist[initialIndex].url;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12, width: 1),
      ),
      onSelected: (value) async {
        final streamUrl = _getStreamUrl();
        if (streamUrl.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active stream URL found.')),
          );
          return;
        }

        if (value == 'vlc') {
          String? vlcPath;
          final paths = [
            r'C:\Program Files\VideoLAN\VLC\vlc.exe',
            r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe',
          ];
          for (final path in paths) {
            if (File(path).existsSync()) {
              vlcPath = path;
              break;
            }
          }
          try {
            if (vlcPath != null) {
              await Process.start(vlcPath, [streamUrl]);
            } else {
              await Process.start('vlc', [streamUrl], runInShell: true);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening stream in VLC...')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open VLC. Please make sure VLC is installed.'),
              ),
            );
          }
        } else if (value == 'copy') {
          await Clipboard.setData(ClipboardData(text: streamUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stream link copied to clipboard!')),
          );
        } else if (value == 'download') {
          try {
            await Process.run('start', [streamUrl], runInShell: true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening download link in browser...')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to open browser.')),
            );
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'vlc',
          child: Row(
            children: [
              Icon(Icons.play_circle_outline, color: Colors.white70, size: 20),
              SizedBox(width: 10),
              Text('Open in VLC', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, color: Colors.white70, size: 20),
              SizedBox(width: 10),
              Text('Copy Stream Link', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'download',
          child: Row(
            children: [
              Icon(Icons.download, color: Colors.white70, size: 20),
              SizedBox(width: 10),
              Text('Download', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}

String _getLanguageName(String code) {
  switch (code.toUpperCase()) {
    case 'ENG': case 'EN': return 'English';
    case 'ITA': case 'IT': return 'Italian';
    case 'FRA': case 'FRE': case 'FR': return 'French';
    case 'GER': case 'DEU': case 'DE': return 'German';
    case 'SPA': case 'ES': return 'Spanish';
    case 'JPN': case 'JA': return 'Japanese';
    case 'KOR': case 'KO': return 'Korean';
    case 'CHI': case 'ZHO': case 'ZH': return 'Chinese';
    case 'RUS': case 'RU': return 'Russian';
    case 'HIN': case 'HI': return 'Hindi';
    case 'POR': case 'PT': return 'Portuguese';
    case 'ARA': case 'AR': return 'Arabic';
    case 'TUR': case 'TR': return 'Turkish';
    case 'POL': case 'PL': return 'Polish';
    case 'NLD': case 'DUT': case 'NL': return 'Dutch';
    case 'UND': return 'Unknown';
    default: return code.toUpperCase();
  }
}

class AudioTrackSelector extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onActivity;
  const AudioTrackSelector({super.key, required this.controller, required this.onActivity});

  Widget _buildBadge(String text, {bool isLang = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLang ? Colors.white.withOpacity(0.15) : Colors.transparent,
        border: isLang ? null : Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: isLang ? Colors.white : Colors.white70, fontSize: 11, fontWeight: isLang ? FontWeight.bold : FontWeight.normal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaInfo = controller.getMediaInfo();
    final audioTracks = mediaInfo?.audio ?? [];
    if (audioTracks.isEmpty) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.audiotrack, color: Colors.white),
      tooltip: 'Audio Tracks',
      onPressed: () {
        onActivity();
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white12, width: 1),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Audio Tracks', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: audioTracks.length + 1,
                        itemBuilder: (context, index) {
                          final activeIds = controller.getActiveAudioTracks() ?? [];
                          final activeId = activeIds.isNotEmpty ? activeIds.first : -1;
                          
                          if (index == 0) {
                            final isSelected = activeId == -1; // Fallback heuristic
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              title: Text('Auto', style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
                              trailing: isSelected ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                              onTap: () {
                                controller.setAudioTracks([-1]);
                                Navigator.pop(context);
                              },
                            );
                          }

                          final track = audioTracks[index - 1];
                          final listPosition = index - 1;
                          final isSelected = listPosition == activeId;
                          
                          final title = track.metadata['title'] ?? '';
                          String rawLang = track.metadata['language']?.toUpperCase() ?? 'UND';
                          
                          if (rawLang == 'UND' || rawLang.isEmpty) {
                            final upTitle = title.toUpperCase();
                            if (upTitle.contains('ENG')) rawLang = 'ENG';
                            else if (upTitle.contains('ITA')) rawLang = 'ITA';
                            else if (upTitle.contains('FRE') || upTitle.contains('FRA')) rawLang = 'FRE';
                            else if (upTitle.contains('GER') || upTitle.contains('DEU')) rawLang = 'GER';
                            else if (upTitle.contains('SPA')) rawLang = 'SPA';
                            else if (upTitle.contains('JPN')) rawLang = 'JPN';
                            else if (upTitle.contains('KOR')) rawLang = 'KOR';
                            else if (upTitle.contains('HIN')) rawLang = 'HIN';
                          }

                          final lang = _getLanguageName(rawLang);
                          final channels = track.codec.channels;
                          String channelStr = '';
                          if (channels == 2) channelStr = '2.0';
                          else if (channels == 6) channelStr = '5.1';
                          else if (channels == 8) channelStr = '7.1';
                          else if (channels > 0) channelStr = '$channels ch';

                          final codec = track.codec.codec.toUpperCase();
                          String badge = '';
                          if (codec.contains('EAC3') || codec.contains('AC3')) badge = 'Dolby';
                          else if (codec.contains('TRUEHD')) badge = 'TrueHD';
                          else if (codec.contains('DTS')) badge = 'DTS';
                          else badge = codec;

                          final bitRate = track.codec.bitRate > 0 ? '${(track.codec.bitRate / 1000).round()} kbps' : '';
                          final sampleRate = track.codec.sampleRate > 0 ? '${(track.codec.sampleRate / 1000).toStringAsFixed(1)} kHz' : '';
                          final mainTitle = title.isNotEmpty && title.toUpperCase() != lang ? title : 'Track ${track.index}';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            title: Row(
                              children: [
                                _buildBadge(lang, isLang: true),
                                Expanded(
                                  child: Text(mainTitle, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 15), overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 16),
                                if (bitRate.isNotEmpty) _buildBadge(bitRate),
                                if (sampleRate.isNotEmpty) _buildBadge(sampleRate),
                                if (channelStr.isNotEmpty) _buildBadge(channelStr),
                                if (badge.isNotEmpty) _buildBadge(badge),
                              ],
                            ),
                            trailing: isSelected ? const Icon(Icons.check, color: Colors.blueAccent) : const SizedBox(width: 24),
                            onTap: () {
                              controller.setAudioTracks([listPosition]);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class SubtitleTrackSelector extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onActivity;
  const SubtitleTrackSelector({super.key, required this.controller, required this.onActivity});

  Widget _buildBadge(String text, {bool isLang = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLang ? Colors.white.withOpacity(0.15) : Colors.transparent,
        border: isLang ? null : Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: isLang ? Colors.white : Colors.white70, fontSize: 11, fontWeight: isLang ? FontWeight.bold : FontWeight.normal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaInfo = controller.getMediaInfo();
    final subTracks = mediaInfo?.subtitle ?? [];
    if (subTracks.isEmpty) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.subtitles, color: Colors.white),
      tooltip: 'Subtitles',
      onPressed: () {
        onActivity();
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white12, width: 1),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Subtitles', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: subTracks.length + 2,
                        itemBuilder: (context, index) {
                          final activeIds = controller.getActiveSubtitleTracks() ?? [];
                          final activeId = activeIds.isNotEmpty ? activeIds.first : -1;
                          
                          if (index == 0) {
                            final isSelected = activeIds.isEmpty;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              title: Text('Disabled', style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
                              trailing: isSelected ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                              onTap: () {
                                controller.setSubtitleTracks([]);
                                Navigator.pop(context);
                              },
                            );
                          }
                          
                          if (index == 1) {
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              title: const Text('Auto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 16)),
                              onTap: () {
                                controller.setSubtitleTracks([-1]);
                                Navigator.pop(context);
                              },
                            );
                          }

                          final track = subTracks[index - 2];
                          final listPosition = index - 2;
                          final isSelected = listPosition == activeId && activeIds.isNotEmpty;
                          
                          final title = track.metadata['title'] ?? '';
                          String rawLang = track.metadata['language']?.toUpperCase() ?? 'UND';
                          
                          if (rawLang == 'UND' || rawLang.isEmpty) {
                            final upTitle = title.toUpperCase();
                            if (upTitle.contains('ENG')) rawLang = 'ENG';
                            else if (upTitle.contains('ITA')) rawLang = 'ITA';
                            else if (upTitle.contains('FRE') || upTitle.contains('FRA')) rawLang = 'FRE';
                            else if (upTitle.contains('GER') || upTitle.contains('DEU')) rawLang = 'GER';
                            else if (upTitle.contains('SPA')) rawLang = 'SPA';
                            else if (upTitle.contains('JPN')) rawLang = 'JPN';
                            else if (upTitle.contains('KOR')) rawLang = 'KOR';
                            else if (upTitle.contains('HIN')) rawLang = 'HIN';
                          }

                          final lang = _getLanguageName(rawLang);
                          final mainTitle = title.isNotEmpty && title.toUpperCase() != lang ? title : 'Track ${track.index}';
                          
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            title: Row(
                              children: [
                                _buildBadge(lang, isLang: true),
                                Expanded(
                                  child: Text(mainTitle, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 15), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            trailing: isSelected ? const Icon(Icons.check, color: Colors.blueAccent) : const SizedBox(width: 24),
                            onTap: () {
                              controller.setSubtitleTracks([listPosition]);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class FullscreenButton extends StatelessWidget {
  final VoidCallback onActivity;
  final bool isFullscreen;
  final VoidCallback onToggle;
  
  const FullscreenButton({
    super.key,
    required this.onActivity,
    required this.isFullscreen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
      onPressed: () {
        onActivity();
        onToggle();
      },
    );
  }
}

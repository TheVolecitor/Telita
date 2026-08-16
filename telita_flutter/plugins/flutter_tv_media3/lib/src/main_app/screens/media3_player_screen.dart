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
import 'package:http/http.dart' as http;
import '../../overlay/screens/components/widgets/brand_loading_indicator.dart';

class _AppCaption {
  final Duration start;
  final Duration end;
  final String text;

  _AppCaption({required this.start, required this.end, required this.text});
}

List<_AppCaption> _parseSrtOrVtt(String content) {
  final List<_AppCaption> captions = [];
  final blocks = content.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
  for (final block in blocks) {
    final lines = block.trim().split('\n');
    for (int i = 0; i < lines.length; i++) {
      final timeMatch = RegExp(
        r'(\d+):(\d+):(\d+)[,\.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,\.](\d+)',
      ).firstMatch(lines[i]);
      if (timeMatch != null && i + 1 < lines.length) {
        final start = Duration(
          hours: int.parse(timeMatch[1]!),
          minutes: int.parse(timeMatch[2]!),
          seconds: int.parse(timeMatch[3]!),
          milliseconds: int.parse(timeMatch[4]!),
        );
        final end = Duration(
          hours: int.parse(timeMatch[5]!),
          minutes: int.parse(timeMatch[6]!),
          seconds: int.parse(timeMatch[7]!),
          milliseconds: int.parse(timeMatch[8]!),
        );
        final textLines =
            lines
                .sublist(i + 1)
                .where((l) => !RegExp(r'^\d+$').hasMatch(l))
                .toList();
        final text =
            textLines.join('\n').replaceAll(RegExp(r'<[^>]*>'), '').trim();
        if (text.isNotEmpty) {
          captions.add(_AppCaption(start: start, end: end, text: text));
        }
        break;
      }
    }
  }
  return captions;
}

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
    if ((Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS ||
        Platform.isAndroid ||
        Platform.isIOS)) {
      _loadingTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted &&
            FtvMedia3PlayerController().videoPlayerController == null) {
          setState(() => _loadingTimedOut = true);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!(Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS ||
          Platform.isAndroid ||
          Platform.isIOS)) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
      try {
        if ((Platform.isWindows ||
            Platform.isLinux ||
            Platform.isMacOS ||
            Platform.isAndroid ||
            Platform.isIOS)) {
          _overlayController = Media3UiController();
          _overlayController!.initForWindows(
            widget.playlist,
            widget.initialIndex,
          );
          setState(() {});
        }
        await _controller.openNativePlayer(
          playlist: widget.playlist,
          initialIndex: widget.initialIndex,
        );
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar(context, e.toString());
          if ((Platform.isWindows ||
              Platform.isLinux ||
              Platform.isMacOS ||
              Platform.isAndroid ||
              Platform.isIOS)) {
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
    if (state == AppLifecycleState.paused &&
        mounted &&
        !isClose &&
        !(Platform.isWindows ||
            Platform.isLinux ||
            Platform.isMacOS ||
            Platform.isAndroid ||
            Platform.isIOS)) {
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
    if ((Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS ||
        Platform.isAndroid ||
        Platform.isIOS)) {
      final controller = FtvMedia3PlayerController().videoPlayerController;
      if (controller == null) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child:
                    _loadingTimedOut
                        ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white54,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Player failed to load',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'MPV did not initialize in time.',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text('Go Back'),
                            ),
                          ],
                        )
                        : const BrandLoadingIndicator(
                          size: 72,
                          color: AppTheme.fullFocusColor,
                        ),
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
  bool _wasPlaying = false;
  bool _videoCompleted = false;
  late final FocusNode _rootFocusNode;
  late final FocusNode _playButtonFocusNode;

  List<_AppCaption> _externalCaptions = [];
  int _activeExternalSubIndex = -1;

  Future<void> _loadExternalSubtitle(int index, String url) async {
    setState(() {
      _activeExternalSubIndex = index;
      _externalCaptions = [];
    });
    try {
      widget.controller.setSubtitleTracks([]);
    } catch (_) {}

    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final parsed = _parseSrtOrVtt(res.body);
        setState(() {
          _externalCaptions = parsed;
        });
      }
    } catch (_) {}
  }

  void _disableExternalSubtitle() {
    setState(() {
      _activeExternalSubIndex = -1;
      _externalCaptions = [];
    });
    try {
      widget.controller.setSubtitleTracks([]);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();
    _playButtonFocusNode = FocusNode();
    _isInitialized = widget.controller.value.isInitialized;
    widget.controller.addListener(_checkInit);
    _subtitleStyle = widget.overlayController?.playerState.subtitleStyle;
    _styleSubscription = widget.overlayController?.playerStateStream.listen((
      state,
    ) {
      if (mounted && state.subtitleStyle != _subtitleStyle) {
        setState(() => _subtitleStyle = state.subtitleStyle);
      }
    });
    _historyTimer = Timer.periodic(
      const Duration(seconds: 5),
      _syncWatchHistory,
    );
  }

  void _syncWatchHistory([Timer? _]) {
    if (!mounted) return;
    final value = widget.controller.value;
    if (!value.isInitialized || value.duration == Duration.zero) return;

    final positionSec = value.position.inSeconds;
    final durationSec = value.duration.inSeconds;

    if (durationSec == 0 || positionSec <= 5) return;

    if (widget.initialIndex >= 0 &&
        widget.initialIndex < widget.playlist.length) {
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
    if (mounted) {
      if (widget.controller.value.isInitialized != _isInitialized) {
        setState(() => _isInitialized = widget.controller.value.isInitialized);

        if (_isInitialized && !_defaultAudioSelected) {
          _defaultAudioSelected = true;
          _selectDefaultAudioTrack();
          _selectDefaultSubtitleTrack();
          // Resume from saved watch position
          final item =
              widget.playlist.isNotEmpty &&
                      widget.initialIndex >= 0 &&
                      widget.initialIndex < widget.playlist.length
                  ? widget.playlist[widget.initialIndex]
                  : null;
          final start = item?.startPosition;
          if (start != null && start > 5) {
            // Small delay so fvp has fully buffered enough to accept a seek
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                widget.controller.seekTo(Duration(seconds: start));
              }
            });
          }
        }
      }

      if (widget.controller.value.isPlaying != _wasPlaying) {
        _wasPlaying = widget.controller.value.isPlaying;
        _sendScrobbleEvent(_wasPlaying ? 'start' : 'pause');
      }
    }
  }

  void _sendScrobbleEvent(String action) {
    if (widget.initialIndex >= 0 &&
        widget.initialIndex < widget.playlist.length) {
      final item = widget.playlist[widget.initialIndex];
      if (item.onScrobble != null) {
        final pos = widget.controller.value.position.inSeconds;
        final dur = widget.controller.value.duration.inSeconds;
        if (dur > 0) {
          item.onScrobble!(action: action, position: pos, duration: dur);
        }
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
        try {
          widget.controller.setAudioTracks([0]);
        } catch (_) {}
        return;
      }

      try {
        int targetPosition = 0; // fallback to first track (0-based)
        for (int i = 0; i < audioTracks.length; i++) {
          final lang = audioTracks[i].metadata['language']?.toUpperCase() ?? '';
          final title = audioTracks[i].metadata['title']?.toUpperCase() ?? '';

          if (lang == 'ENG' ||
              lang == 'EN' ||
              lang == 'ENGLISH' ||
              title.contains('ENG') ||
              title.contains('ENGLISH')) {
            targetPosition = i;
            break;
          }
        }
        widget.controller.setAudioTracks([targetPosition]);
      } catch (_) {}
    });
  }

  void _selectDefaultSubtitleTrack() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      final playerSettings =
          widget.overlayController?.playerState.playerSettings;
      final subtitleEnabled = playerSettings?.forcedAutoEnable ?? true;

      if (!subtitleEnabled) {
        try {
          widget.controller.setSubtitleTracks([]);
        } catch (_) {}
        _disableExternalSubtitle();
        return;
      }

      final preferredLangs =
          playerSettings?.preferredTextLanguages ?? const ['eng'];
      final prefLang =
          preferredLangs.isNotEmpty
              ? preferredLangs.first.toLowerCase()
              : 'eng';

      // 1. PRIORITIZE IN-STREAM CONTAINER SUBTITLES FIRST
      final mediaInfo = widget.controller.getMediaInfo();
      final subTracks = mediaInfo?.subtitle ?? [];

      int matchedInStreamIndex = -1;
      for (int i = 0; i < subTracks.length; i++) {
        final lang = (subTracks[i].metadata['language'] ?? '').toLowerCase();
        final title = (subTracks[i].metadata['title'] ?? '').toLowerCase();

        if (lang == prefLang ||
            lang.startsWith(prefLang) ||
            title.contains(prefLang) ||
            (prefLang == 'eng' &&
                (lang == 'en' || lang == 'english' || title.contains('eng')))) {
          matchedInStreamIndex = i;
          break;
        }
      }

      if (matchedInStreamIndex != -1) {
        _disableExternalSubtitle();
        try {
          widget.controller.setSubtitleTracks([matchedInStreamIndex]);
        } catch (_) {}
        return;
      }

      // 2. IF NO IN-STREAM SUBTITLE FOUND FOR PREFERRED LANG, CHECK EXTERNAL ADDON SUBTITLES
      final item =
          widget.playlist.isNotEmpty &&
                  widget.initialIndex >= 0 &&
                  widget.initialIndex < widget.playlist.length
              ? widget.playlist[widget.initialIndex]
              : null;
      final externalSubs = item?.subtitles ?? [];

      if (externalSubs.isNotEmpty && _activeExternalSubIndex == -1) {
        int matchedExtIndex = -1;
        for (int i = 0; i < externalSubs.length; i++) {
          final lang = externalSubs[i].language.toLowerCase();
          if (lang == prefLang ||
              lang.startsWith(prefLang) ||
              (prefLang == 'eng' && (lang == 'en' || lang == 'english'))) {
            matchedExtIndex = i;
            break;
          }
        }

        final targetIdx = matchedExtIndex != -1 ? matchedExtIndex : 0;
        _loadExternalSubtitle(targetIdx, externalSubs[targetIdx].url);
        return;
      }

      // 3. FALLBACK: IF NO MATCHING LANG IN-STREAM OR EXTERNAL, PICK FIRST AVAILABLE IN-STREAM TRACK
      if (subTracks.isNotEmpty) {
        _disableExternalSubtitle();
        try {
          widget.controller.setSubtitleTracks([0]);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    if (_isFullscreen) {
      acrylic.Window.exitFullscreen();
      _isFullscreen = false;
    }
    _rootFocusNode.dispose();
    _playButtonFocusNode.dispose();
    _sendScrobbleEvent('stop');
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
        _rootFocusNode.requestFocus();
        _unmountTimer = Timer(const Duration(milliseconds: 250), () {
          if (mounted) setState(() => _controlsMounted = false);
        });
      }
    });
  }

  void _togglePlay() {
    widget.controller.value.isPlaying
        ? widget.controller.pause()
        : widget.controller.play();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (_isFullscreen) {
        acrylic.Window.enterFullscreen();
      } else {
        acrylic.Window.exitFullscreen();
      }
    } else {
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft,
        ]);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft,
        ]);
      }
    }
  }

  void _seek(Duration delta) {
    final next = widget.controller.value.position + delta;
    widget.controller.seekTo(next.isNegative ? Duration.zero : next);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    _onMouseActivity();

    // hasPrimaryFocus = ONLY this exact node is focused (no child button is focused).
    // If a child button has focus, hasPrimaryFocus is false — let Flutter traversal
    // and the child's own onKeyEvent handle the event.
    if (!node.hasPrimaryFocus) {
      // Only intercept global Back/Escape — everything else propagates to the focused child.
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        if (_isFullscreen) {
          _toggleFullscreen();
        } else {
          widget.onBack();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Root has primary focus — player surface is in control.
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.gameButtonA:
        _togglePlay();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (_controlsVisible) {
          // Controls visible: move focus rightward in controls
          FocusScope.of(context).focusInDirection(TraversalDirection.right);
        } else {
          _seek(const Duration(seconds: 10));
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        if (_controlsVisible) {
          FocusScope.of(context).focusInDirection(TraversalDirection.left);
        } else {
          _seek(const Duration(seconds: -10));
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        // Move focus down into the controls bar (play button).
        if (_controlsVisible && _controlsMounted) {
          _playButtonFocusNode.requestFocus();
        } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          widget.controller.setVolume(
            (widget.controller.value.volume - 0.05).clamp(0.0, 1.0),
          );
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          widget.controller.setVolume(
            (widget.controller.value.volume + 0.05).clamp(0.0, 1.0),
          );
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        if (_isFullscreen) {
          _toggleFullscreen();
        } else {
          widget.onBack();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          _controlsVisible ? SystemMouseCursors.basic : SystemMouseCursors.none,
      onHover: (_) => _onMouseActivity(),
      onEnter: (_) => _onMouseActivity(),
      child: Focus(
        focusNode: _rootFocusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video fills the entire space with no built-in controls overlay.
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (_controlsVisible) {
                    setState(() => _controlsVisible = false);
                  } else {
                    _onMouseActivity();
                  }
                },
                onDoubleTap: _toggleFullscreen,
                child: RepaintBoundary(
                  child:
                      _isInitialized
                          ? Center(
                            child: AspectRatio(
                              aspectRatio: widget.controller.value.aspectRatio,
                              child: VideoPlayer(widget.controller),
                            ),
                          )
                          : const Center(
                            child: BrandLoadingIndicator(
                              size: 72,
                              color: AppTheme.fullFocusColor,
                            ),
                          ),
                ),
              ),
            ),

            // Error or Buffering indicator
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: widget.controller,
              builder: (context, value, child) {
                if (value.hasError) {
                  final item =
                      widget.playlist.isNotEmpty &&
                              widget.initialIndex >= 0 &&
                              widget.initialIndex < widget.playlist.length
                          ? widget.playlist[widget.initialIndex]
                          : null;
                  return Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white54,
                            size: 64,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Playback Error',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48.0,
                            ),
                            child: Text(
                              value.errorDescription ??
                                  'Unknown error occurred.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 15,
                              ),
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
                                  backgroundColor: Colors.white.withOpacity(
                                    0.1,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: () {
                                  // Can't easily restart a failed fvp instance from overlay
                                  // Exit and let the user click the item again.
                                  widget.onBack();
                                },
                              ),
                              if (item?.url != null &&
                                  item!.url.isNotEmpty) ...[
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Open in VLC'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(
                                      0.1,
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: () {
                                    if (Platform.isWindows) {
                                      Process.start('cmd', [
                                        '/c',
                                        'start',
                                        '',
                                        'vlc',
                                        item.url,
                                      ]);
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
                                    backgroundColor: Colors.white.withOpacity(
                                      0.1,
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: () {
                                    if (Platform.isWindows) {
                                      Process.start('cmd', [
                                        '/c',
                                        'start',
                                        '',
                                        'mpv',
                                        item.url,
                                      ]);
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

            // Vector Native Subtitle Overlay
            if (_activeExternalSubIndex != -1 && _externalCaptions.isNotEmpty)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: widget.controller,
                builder: (context, val, _) {
                  if (!val.isInitialized) return const SizedBox.shrink();
                  final pos = val.position;
                  String captionText = '';
                  for (final cap in _externalCaptions) {
                    if (pos >= cap.start && pos <= cap.end) {
                      captionText = cap.text;
                      break;
                    }
                  }
                  if (captionText.isEmpty) return const SizedBox.shrink();

                  final style = _subtitleStyle ?? SubtitleStyle();
                  final fgColor = style.foregroundColor?.color ?? Colors.white;
                  final bgColor =
                      style.backgroundColor?.color ?? Colors.transparent;
                  final winColor =
                      style.windowColor?.color ?? Colors.transparent;

                  final fontSizeMultiplier = style.textSizeFraction ?? 1.0;
                  final baseFontSize = 32.0 * fontSizeMultiplier;

                  final bottomPad =
                      (style.bottomPadding?.toDouble() ?? 0.0) +
                      (_controlsVisible ? 110.0 : 48.0);
                  final leftPad = (style.leftPadding?.toDouble() ?? 0.0) + 48.0;
                  final rightPad =
                      (style.rightPadding?.toDouble() ?? 0.0) + 48.0;

                  List<Shadow>? textShadows;
                  if (style.edgeType == SubtitleEdgeType.dropShadow) {
                    textShadows = [
                      Shadow(
                        blurRadius: 0,
                        color: style.edgeColor?.color ?? Colors.black,
                        offset: const Offset(-1, -1),
                      ),
                      Shadow(
                        blurRadius: 0,
                        color: style.edgeColor?.color ?? Colors.black,
                        offset: const Offset(1, -1),
                      ),
                      Shadow(
                        blurRadius: 0,
                        color: style.edgeColor?.color ?? Colors.black,
                        offset: const Offset(1, 1),
                      ),
                      Shadow(
                        blurRadius: 0,
                        color: style.edgeColor?.color ?? Colors.black,
                        offset: const Offset(-1, 1),
                      ),
                      Shadow(
                        blurRadius: 4,
                        color: style.edgeColor?.color ?? Colors.black,
                        offset: const Offset(2, 2),
                      ),
                    ];
                  } else if (style.edgeType == SubtitleEdgeType.outline) {
                    final edgeCol = style.edgeColor?.color ?? Colors.black;
                    textShadows = [
                      Shadow(
                        blurRadius: 0,
                        color: edgeCol,
                        offset: const Offset(-1, -1),
                      ),
                      Shadow(
                        blurRadius: 0,
                        color: edgeCol,
                        offset: const Offset(1, -1),
                      ),
                      Shadow(
                        blurRadius: 0,
                        color: edgeCol,
                        offset: const Offset(1, 1),
                      ),
                      Shadow(
                        blurRadius: 0,
                        color: edgeCol,
                        offset: const Offset(-1, 1),
                      ),
                    ];
                  } else if (style.edgeType == SubtitleEdgeType.raised) {
                    textShadows = [
                      Shadow(
                        blurRadius: 2,
                        color: style.edgeColor?.color ?? Colors.black,
                        offset: const Offset(-1, -1),
                      ),
                    ];
                  } else if (style.edgeType == SubtitleEdgeType.depressed) {
                    textShadows = [
                      Shadow(
                        blurRadius: 2,
                        color: style.edgeColor?.color ?? Colors.black,
                        offset: const Offset(1, 1),
                      ),
                    ];
                  } else {
                    // Thin black boundary outline + soft drop shadow
                    textShadows = const [
                      Shadow(
                        blurRadius: 0,
                        color: Colors.black,
                        offset: Offset(-1, -1),
                      ),
                      Shadow(
                        blurRadius: 0,
                        color: Colors.black,
                        offset: Offset(1, -1),
                      ),
                      Shadow(
                        blurRadius: 0,
                        color: Colors.black,
                        offset: Offset(1, 1),
                      ),
                      Shadow(
                        blurRadius: 0,
                        color: Colors.black,
                        offset: Offset(-1, 1),
                      ),
                      Shadow(
                        blurRadius: 3,
                        color: Colors.black54,
                        offset: Offset(1.5, 1.5),
                      ),
                    ];
                  }

                  final Color containerColor =
                      (winColor != Colors.transparent && winColor.alpha > 0)
                          ? winColor
                          : (bgColor != Colors.transparent && bgColor.alpha > 0)
                          ? bgColor
                          : Colors.transparent;

                  return Positioned(
                    bottom: bottomPad,
                    left: leftPad,
                    right: rightPad,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: containerColor,
                            borderRadius:
                                containerColor != Colors.transparent
                                    ? BorderRadius.circular(8)
                                    : null,
                          ),
                          child: Text(
                            captionText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Arial',
                              fontFamilyFallback: const [
                                'Roboto',
                                'Segoe UI',
                                'sans-serif',
                              ],
                              color: fgColor,
                              fontSize: baseFontSize,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                              shadows: textShadows,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
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
                    playButtonFocusNode: _playButtonFocusNode,
                    onBackToPlayer: () => _rootFocusNode.requestFocus(),
                    externalSubtitles:
                        (widget.playlist.isNotEmpty &&
                                widget.initialIndex >= 0 &&
                                widget.initialIndex < widget.playlist.length)
                            ? (widget.playlist[widget.initialIndex].subtitles ??
                                const [])
                            : const [],
                    activeExternalSubIndex: _activeExternalSubIndex,
                    onSelectExternalSubtitle:
                        (idx, url) => _loadExternalSubtitle(idx, url),
                    onDisableExternalSubtitle: _disableExternalSubtitle,
                  ),
                ),
              ),
            _WindowsSkipSegmentOverlay(
              controller: widget.controller,
              playItem:
                  widget.playlist.isNotEmpty &&
                          widget.initialIndex >= 0 &&
                          widget.initialIndex < widget.playlist.length
                      ? widget.playlist[widget.initialIndex]
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
  final PlaylistMediaItem? playItem;

  const _WindowsSkipSegmentOverlay({
    required this.controller,
    required this.playItem,
  });

  @override
  State<_WindowsSkipSegmentOverlay> createState() =>
      _WindowsSkipSegmentOverlayState();
}

class _WindowsSkipSegmentOverlayState
    extends State<_WindowsSkipSegmentOverlay> {
  bool _isFocused = false;
  bool _hasAutoAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final playItem = widget.playItem;
    if (playItem == null) return const SizedBox.shrink();

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        if (!value.isInitialized || value.duration == Duration.zero) {
          return const SizedBox.shrink();
        }

        final currentMs = value.position.inMilliseconds;
        final durationMs = value.duration.inMilliseconds;
        final currentSecs = currentMs ~/ 1000;
        final remainingMs = durationMs - currentMs;
        final double remainingSecs = remainingMs / 1000.0;
        final bool isNextEpisode =
            playItem.hasNextEpisode &&
            durationMs > 0 &&
            remainingSecs <= 10.0 &&
            remainingSecs >= 0.0;

        // Auto-advance: when video naturally ends, trigger next episode
        if (!_hasAutoAdvanced &&
            playItem.hasNextEpisode &&
            durationMs > 0 &&
            remainingMs <= 0) {
          _hasAutoAdvanced = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.controller.pause();
              playItem.onNextEpisode?.call();
            }
          });
        }

        MediaSegment? active;
        if (!isNextEpisode &&
            playItem.segments != null &&
            playItem.segments!.isNotEmpty) {
          for (final seg in playItem.segments!) {
            final start = seg.startSec ?? 0;
            if (currentSecs >= start && currentSecs < seg.endSec) {
              active = seg;
              break;
            }
          }
        }

        if (active == null && !isNextEpisode) {
          return const SizedBox.shrink();
        }

        // --- UpNext Card ---
        if (isNextEpisode) {
          final double progress = (1.0 - (remainingMs / 10000.0)).clamp(
            0.0,
            1.0,
          );
          final seasonStr = playItem.nextEpisodeSeason?.toString();
          final epStr = playItem.nextEpisodeNumber?.toString();
          String sxe = "";
          if (seasonStr != null && epStr != null) {
            sxe = "S${seasonStr}E${epStr}";
          }

          return Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 110.0, right: 32.0),
              child: MouseRegion(
                onEnter: (_) => setState(() => _isFocused = true),
                onExit: (_) => setState(() => _isFocused = false),
                child: GestureDetector(
                  onTap: () {
                    widget.controller.pause();
                    playItem.onNextEpisode?.call();
                  },
                  child: Container(
                    width: 320,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isFocused ? Colors.white : Colors.white24,
                        width: _isFocused ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                        if (_isFocused)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          if (playItem.nextEpisodeThumbnail != null &&
                              playItem.nextEpisodeThumbnail!.isNotEmpty)
                            Positioned.fill(
                              child: Image.network(
                                playItem.nextEpisodeThumbnail!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const SizedBox.shrink(),
                              ),
                            ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.4),
                                    Colors.black.withOpacity(0.85),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.skip_next,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'UP NEXT',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                if (sxe.isNotEmpty)
                                  Text(
                                    sxe,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                if (playItem.nextEpisodeTitle != null)
                                  Text(
                                    playItem.nextEpisodeTitle!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 4,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                remainingSecs.ceil().clamp(0, 10).toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // --- Skip Intro/Recap/Credits ---
        final label =
            active!.type.toLowerCase() == 'intro'
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isFocused
                            ? AppTheme.fullFocusColor
                            : Colors.black.withOpacity(0.85),
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
  final List<MediaItemSubtitle> externalSubtitles;
  final int activeExternalSubIndex;
  final Function(int index, String url) onSelectExternalSubtitle;
  final VoidCallback onDisableExternalSubtitle;
  final FocusNode playButtonFocusNode;
  final VoidCallback onBackToPlayer;

  const _ControlsOverlay({
    super.key,
    required this.controller,
    required this.playlist,
    required this.initialIndex,
    required this.onBack,
    required this.onActivity,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.externalSubtitles = const [],
    this.activeExternalSubIndex = -1,
    required this.onSelectExternalSubtitle,
    required this.onDisableExternalSubtitle,
    required this.playButtonFocusNode,
    required this.onBackToPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Stack(
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
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(0),
                    child: _TvIconButton(
                      icon: Icons.arrow_back,
                      onPressed: onBack,
                      tooltip: 'Back',
                    ),
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
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: _SeekBar(
                        controller: controller,
                        onActivity: onActivity,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Play / pause
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, val, _) {
                            final playing = val.isPlaying;
                            return FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: _TvIconButton(
                                focusNode: playButtonFocusNode,
                                icon: playing ? Icons.pause : Icons.play_arrow,
                                tooltip: playing ? 'Pause' : 'Play',
                                onPressed: () {
                                  onActivity();
                                  playing
                                      ? controller.pause()
                                      : controller.play();
                                },
                                onUpKey: onBackToPlayer,
                              ),
                            );
                          },
                        ),
                        // Position / duration
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, val, _) {
                            return Text(
                              '${_fmt(val.position)} / ${_fmt(val.duration)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(3),
                          child: SubtitleTrackSelector(
                            controller: controller,
                            onActivity: onActivity,
                            externalSubtitles: externalSubtitles,
                            activeExternalSubIndex: activeExternalSubIndex,
                            onSelectExternalSubtitle: onSelectExternalSubtitle,
                            onDisableExternalSubtitle:
                                onDisableExternalSubtitle,
                          ),
                        ),
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(4),
                          child: AudioTrackSelector(
                            controller: controller,
                            onActivity: onActivity,
                          ),
                        ),
                        // Volume
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, val, _) {
                            final vol = val.volume;
                            return FocusTraversalOrder(
                              order: const NumericFocusOrder(5),
                              child: _TvIconButton(
                                icon:
                                    vol == 0
                                        ? Icons.volume_off
                                        : vol < 0.5
                                        ? Icons.volume_down
                                        : Icons.volume_up,
                                tooltip: 'Volume',
                                onPressed: () {
                                  onActivity();
                                  controller.setVolume(vol > 0 ? 0 : 1.0);
                                },
                              ),
                            );
                          },
                        ),

                        FocusTraversalOrder(
                          order: const NumericFocusOrder(6),
                          child: FullscreenButton(
                            onActivity: onActivity,
                            isFullscreen: isFullscreen,
                            onToggle: onToggleFullscreen,
                          ),
                        ),
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(7),
                          child: PlayerMoreMenuButton(
                            controller: controller,
                            playlist: playlist,
                            initialIndex: initialIndex,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
  const _SeekBar({
    super.key,
    required this.controller,
    required this.onActivity,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragging;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(context).focusInDirection(TraversalDirection.down);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(context).focusInDirection(TraversalDirection.up);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

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
            focusNode: _focusNode,
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

// ─────────────────────────────────────────────────────────────────────────────
// TV-focusable icon button – shows a bright ring when focused via D-Pad.
// ─────────────────────────────────────────────────────────────────────────────
class _TvIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;
  final FocusNode? focusNode;
  final VoidCallback? onUpKey;

  const _TvIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 26,
    this.focusNode,
    this.onUpKey,
  });

  @override
  State<_TvIconButton> createState() => _TvIconButtonState();
}

class _TvIconButtonState extends State<_TvIconButton> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Up key: escape controls back to video surface
          if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
              widget.onUpKey != null) {
            widget.onUpKey!();
            return KeyEventResult.handled;
          }
          // TV directional bypass: force traversal order since Spacer breaks geometry
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            FocusScope.of(context).nextFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            FocusScope.of(context).previousFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: IconButton(
        focusNode: widget.focusNode,
        icon: Icon(widget.icon, color: Colors.white, size: widget.size),
        tooltip: widget.tooltip,
        onPressed: widget.onPressed,
      ),
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
                  color:
                      isSelected
                          ? AppTheme.fullFocusColor.withOpacity(0.15)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isSelected
                            ? AppTheme.fullFocusColor
                            : Colors.transparent,
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
                            color:
                                isSelected
                                    ? AppTheme.fullFocusColor
                                    : Colors.white70,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                      ...badges.map(
                        (badgeText) => Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppTheme.fullFocusColor.withOpacity(0.2)
                                    : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppTheme.fullFocusColor.withOpacity(0.5)
                                      : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? AppTheme.fullFocusColor
                                      : Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing:
                      isSelected
                          ? const Icon(
                            Icons.check_circle,
                            color: AppTheme.fullFocusColor,
                          )
                          : null,
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
                content: Text(
                  'Could not open VLC. Please make sure VLC is installed.',
                ),
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
              const SnackBar(
                content: Text('Opening download link in browser...'),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to open browser.')),
            );
          }
        }
      },
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: 'vlc',
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 20,
                  ),
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
                  Text(
                    'Copy Stream Link',
                    style: TextStyle(color: Colors.white),
                  ),
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
  final cleanCode = code.trim().toUpperCase();
  switch (cleanCode) {
    case 'ENG':
    case 'EN':
    case 'ENGLISH':
      return 'English';
    case 'ITA':
    case 'IT':
    case 'ITALIAN':
      return 'Italian';
    case 'FRA':
    case 'FRE':
    case 'FR':
    case 'FRENCH':
      return 'French';
    case 'GER':
    case 'DEU':
    case 'DE':
    case 'GERMAN':
      return 'German';
    case 'SPA':
    case 'ES':
    case 'SPANISH':
      return 'Spanish';
    case 'JPN':
    case 'JA':
    case 'JAPANESE':
      return 'Japanese';
    case 'KOR':
    case 'KO':
    case 'KOREAN':
      return 'Korean';
    case 'CHI':
    case 'ZHO':
    case 'ZH':
    case 'CHINESE':
      return 'Chinese';
    case 'RUS':
    case 'RU':
    case 'RUSSIAN':
      return 'Russian';
    case 'HIN':
    case 'HI':
    case 'HINDI':
      return 'Hindi';
    case 'POR':
    case 'PT':
    case 'PORTUGUESE':
    case 'POB':
    case 'PBR':
      return 'Portuguese';
    case 'ARA':
    case 'AR':
    case 'ARABIC':
      return 'Arabic';
    case 'TUR':
    case 'TR':
    case 'TURKISH':
      return 'Turkish';
    case 'POL':
    case 'PL':
    case 'POLISH':
      return 'Polish';
    case 'NLD':
    case 'DUT':
    case 'NL':
    case 'DUTCH':
      return 'Dutch';
    case 'SWE':
    case 'SV':
    case 'SWEDISH':
      return 'Swedish';
    case 'NOR':
    case 'NO':
    case 'NORWEGIAN':
      return 'Norwegian';
    case 'DAN':
    case 'DA':
    case 'DANISH':
      return 'Danish';
    case 'FIN':
    case 'FI':
    case 'FINNISH':
      return 'Finnish';
    case 'GRE':
    case 'ELL':
    case 'EL':
    case 'GREEK':
      return 'Greek';
    case 'HUN':
    case 'HU':
    case 'HUNGARIAN':
      return 'Hungarian';
    case 'CES':
    case 'CZE':
    case 'CS':
    case 'CZECH':
      return 'Czech';
    case 'RON':
    case 'RUM':
    case 'RO':
    case 'ROMANIAN':
      return 'Romanian';
    case 'HEB':
    case 'HE':
    case 'HEBREW':
      return 'Hebrew';
    case 'VIE':
    case 'VI':
    case 'VIETNAMESE':
      return 'Vietnamese';
    case 'IND':
    case 'ID':
    case 'INDONESIAN':
      return 'Indonesian';
    case 'THA':
    case 'TH':
    case 'THAI':
      return 'Thai';
    case 'UKR':
    case 'UK':
    case 'UKRAINIAN':
      return 'Ukrainian';
    case 'UND':
      return 'Unknown';
    default:
      if (cleanCode.length > 3) {
        return cleanCode[0] + cleanCode.substring(1).toLowerCase();
      }
      return cleanCode;
  }
}

class AudioTrackSelector extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onActivity;
  const AudioTrackSelector({
    super.key,
    required this.controller,
    required this.onActivity,
  });

  Widget _buildBadge(String text, {bool isLang = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLang ? Colors.white.withOpacity(0.15) : Colors.transparent,
        border:
            isLang
                ? null
                : Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isLang ? Colors.white : Colors.white70,
          fontSize: 11,
          fontWeight: isLang ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaInfo = controller.getMediaInfo();
    final audioTracks = mediaInfo?.audio ?? [];
    if (audioTracks.isEmpty) return const SizedBox.shrink();

    return _TvIconButton(
      icon: Icons.audiotrack,
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
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Audio Tracks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: audioTracks.length + 1,
                        itemBuilder: (context, index) {
                          final activeIds =
                              controller.getActiveAudioTracks() ?? [];
                          final activeId =
                              activeIds.isNotEmpty ? activeIds.first : -1;

                          if (index == 0) {
                            final isSelected =
                                activeId == -1; // Fallback heuristic
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              title: Text(
                                'Auto',
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.blueAccent
                                          : Colors.white,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              trailing:
                                  isSelected
                                      ? const Icon(
                                        Icons.check,
                                        color: Colors.blueAccent,
                                      )
                                      : null,
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
                          String rawLang =
                              track.metadata['language']?.toUpperCase() ??
                              'UND';

                          if (rawLang == 'UND' || rawLang.isEmpty) {
                            final upTitle = title.toUpperCase();
                            if (upTitle.contains('ENG'))
                              rawLang = 'ENG';
                            else if (upTitle.contains('ITA'))
                              rawLang = 'ITA';
                            else if (upTitle.contains('FRE') ||
                                upTitle.contains('FRA'))
                              rawLang = 'FRE';
                            else if (upTitle.contains('GER') ||
                                upTitle.contains('DEU'))
                              rawLang = 'GER';
                            else if (upTitle.contains('SPA'))
                              rawLang = 'SPA';
                            else if (upTitle.contains('JPN'))
                              rawLang = 'JPN';
                            else if (upTitle.contains('KOR'))
                              rawLang = 'KOR';
                            else if (upTitle.contains('HIN'))
                              rawLang = 'HIN';
                          }

                          final lang = _getLanguageName(rawLang);
                          final channels = track.codec.channels;
                          String channelStr = '';
                          if (channels == 2)
                            channelStr = '2.0';
                          else if (channels == 6)
                            channelStr = '5.1';
                          else if (channels == 8)
                            channelStr = '7.1';
                          else if (channels > 0)
                            channelStr = '$channels ch';

                          final codec = track.codec.codec.toUpperCase();
                          String badge = '';
                          if (codec.contains('EAC3') || codec.contains('AC3'))
                            badge = 'Dolby';
                          else if (codec.contains('TRUEHD'))
                            badge = 'TrueHD';
                          else if (codec.contains('DTS'))
                            badge = 'DTS';
                          else
                            badge = codec;

                          final bitRate =
                              track.codec.bitRate > 0
                                  ? '${(track.codec.bitRate / 1000).round()} kbps'
                                  : '';
                          final sampleRate =
                              track.codec.sampleRate > 0
                                  ? '${(track.codec.sampleRate / 1000).toStringAsFixed(1)} kHz'
                                  : '';
                          final mainTitle =
                              title.isNotEmpty && title.toUpperCase() != lang
                                  ? title
                                  : 'Track ${track.index}';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            title: Row(
                              children: [
                                _buildBadge(lang, isLang: true),
                                Expanded(
                                  child: Text(
                                    mainTitle,
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.blueAccent
                                              : Colors.white,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                if (bitRate.isNotEmpty) _buildBadge(bitRate),
                                if (sampleRate.isNotEmpty)
                                  _buildBadge(sampleRate),
                                if (channelStr.isNotEmpty)
                                  _buildBadge(channelStr),
                                if (badge.isNotEmpty) _buildBadge(badge),
                              ],
                            ),
                            trailing:
                                isSelected
                                    ? const Icon(
                                      Icons.check,
                                      color: Colors.blueAccent,
                                    )
                                    : const SizedBox(width: 24),
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
  final List<MediaItemSubtitle> externalSubtitles;
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

  Widget _buildBadge(String text, {bool isLang = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLang ? Colors.white.withOpacity(0.15) : Colors.transparent,
        border:
            isLang
                ? null
                : Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isLang ? Colors.white : Colors.white70,
          fontSize: 11,
          fontWeight: isLang ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaInfo = controller.getMediaInfo();
    final subTracks = mediaInfo?.subtitle ?? [];
    if (subTracks.isEmpty && externalSubtitles.isEmpty)
      return const SizedBox.shrink();

    return _TvIconButton(
      icon: Icons.subtitles,
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
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Subtitles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount:
                            subTracks.length + externalSubtitles.length + 1,
                        itemBuilder: (context, index) {
                          final activeIds =
                              controller.getActiveSubtitleTracks() ?? [];
                          final activeId =
                              activeIds.isNotEmpty ? activeIds.first : -1;

                          if (index == 0) {
                            final isSelected =
                                activeIds.isEmpty &&
                                activeExternalSubIndex == -1;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              title: Text(
                                'Disabled',
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.blueAccent
                                          : Colors.white,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  fontSize: 16,
                                ),
                              ),
                              trailing:
                                  isSelected
                                      ? const Icon(
                                        Icons.check,
                                        color: Colors.blueAccent,
                                      )
                                      : null,
                              onTap: () {
                                onDisableExternalSubtitle();
                                controller.setSubtitleTracks([]);
                                Navigator.pop(context);
                              },
                            );
                          }

                          // Internal container tracks
                          if (index - 1 < subTracks.length) {
                            final track = subTracks[index - 1];
                            final listPosition = index - 1;
                            final isSelected =
                                listPosition == activeId &&
                                activeIds.isNotEmpty &&
                                activeExternalSubIndex == -1;

                            final title = track.metadata['title'] ?? '';
                            String rawLang =
                                track.metadata['language']?.toUpperCase() ??
                                'UND';

                            if (rawLang == 'UND' || rawLang.isEmpty) {
                              final upTitle = title.toUpperCase();
                              if (upTitle.contains('ENG'))
                                rawLang = 'ENG';
                              else if (upTitle.contains('ITA'))
                                rawLang = 'ITA';
                              else if (upTitle.contains('FRE') ||
                                  upTitle.contains('FRA'))
                                rawLang = 'FRE';
                              else if (upTitle.contains('GER') ||
                                  upTitle.contains('DEU'))
                                rawLang = 'GER';
                              else if (upTitle.contains('SPA'))
                                rawLang = 'SPA';
                              else if (upTitle.contains('JPN'))
                                rawLang = 'JPN';
                              else if (upTitle.contains('KOR'))
                                rawLang = 'KOR';
                              else if (upTitle.contains('HIN'))
                                rawLang = 'HIN';
                            }

                            final lang = _getLanguageName(rawLang);
                            final mainTitle =
                                title.isNotEmpty && title.toUpperCase() != lang
                                    ? title
                                    : 'Track ${track.index}';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              title: Row(
                                children: [
                                  _buildBadge(lang, isLang: true),
                                  Expanded(
                                    child: Text(
                                      mainTitle,
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? Colors.blueAccent
                                                : Colors.white,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              trailing:
                                  isSelected
                                      ? const Icon(
                                        Icons.check,
                                        color: Colors.blueAccent,
                                      )
                                      : const SizedBox(width: 24),
                              onTap: () {
                                onDisableExternalSubtitle();
                                controller.setSubtitleTracks([listPosition]);
                                Navigator.pop(context);
                              },
                            );
                          }

                          // External addon tracks
                          final extIndex = index - 1 - subTracks.length;
                          final extSub = externalSubtitles[extIndex];
                          final isSelected = activeExternalSubIndex == extIndex;

                          final fullLang = _getLanguageName(extSub.language);
                          final addonTitle =
                              extSub.label.isNotEmpty ? extSub.label : 'Addon';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            title: Row(
                              children: [
                                _buildBadge(fullLang, isLang: true),
                                Expanded(
                                  child: Text(
                                    addonTitle,
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.blueAccent
                                              : Colors.white,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            trailing:
                                isSelected
                                    ? const Icon(
                                      Icons.check,
                                      color: Colors.blueAccent,
                                    )
                                    : const SizedBox(width: 24),
                            onTap: () {
                              onSelectExternalSubtitle(extIndex, extSub.url);
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
    return _TvIconButton(
      icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
      tooltip: isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
      onPressed: () {
        onActivity();
        onToggle();
      },
    );
  }
}

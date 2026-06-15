import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../../flutter_tv_media3.dart';
import 'dart:io';
import '../../overlay/media_ui_service/media3_ui_controller.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../overlay/bloc/overlay_ui_bloc.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
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
    if (Platform.isWindows) {
      _loadingTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && FtvMedia3PlayerController().videoController == null) {
          setState(() => _loadingTimedOut = true);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!Platform.isWindows) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
      try {
        if (Platform.isWindows) {
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
          if (Platform.isWindows) {
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
    if (state == AppLifecycleState.paused && mounted && !isClose && !Platform.isWindows) {
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
    if (Platform.isWindows) {
      final controller = FtvMedia3PlayerController().videoController;
      final player = FtvMedia3PlayerController().player;
      if (controller == null || player == null) {
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
          player: player,
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
  final media_kit.Player player;
  final VideoController controller;
  final List<PlaylistMediaItem> playlist;
  final int initialIndex;
  final VoidCallback onBack;
  final Media3UiController? overlayController;

  const _WindowsDesktopPlayer({
    required this.player,
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
  Timer? _hideTimer;
  static const _hideAfter = Duration(seconds: 3);
  SubtitleStyle? _subtitleStyle;
  StreamSubscription<PlayerState>? _styleSubscription;

  @override
  void initState() {
    super.initState();
    _subtitleStyle = widget.overlayController?.playerState.subtitleStyle;
    _styleSubscription = widget.overlayController?.playerStateStream.listen((state) {
      if (mounted && state.subtitleStyle != _subtitleStyle) {
        setState(() => _subtitleStyle = state.subtitleStyle);
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _styleSubscription?.cancel();
    super.dispose();
  }

  void _onMouseActivity() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    if (!widget.player.state.playing) return; // keep visible when paused
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _togglePlay() {
    widget.player.state.playing ? widget.player.pause() : widget.player.play();
  }

  void _seek(Duration delta) {
    final next = widget.player.state.position + delta;
    widget.player.seek(next.isNegative ? Duration.zero : next);
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
      case LogicalKeyboardKey.arrowRight:
        _seek(const Duration(seconds: 10));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _seek(const Duration(seconds: -10));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        widget.player.setVolume((widget.player.state.volume + 5).clamp(0, 100));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        widget.player.setVolume((widget.player.state.volume - 5).clamp(0, 100));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onBack();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  SubtitleViewConfiguration _buildSubtitleConfig(SubtitleStyle? style) {
    if (style == null) return const SubtitleViewConfiguration();

    final fgColor = style.foregroundColor?.color ?? Colors.white;
    final bgColor = style.backgroundColor?.color ?? Colors.transparent;
    final shadowColor = style.edgeColor?.color ?? Colors.black;
    final sizeFraction = style.textSizeFraction ?? 1.0;
    final baseFontSize = 42.0 * sizeFraction;

    List<Shadow> shadows = [];
    switch (style.edgeType) {
      case SubtitleEdgeType.dropShadow:
        shadows = [Shadow(color: shadowColor, blurRadius: 4, offset: const Offset(2, 2))];
        break;
      case SubtitleEdgeType.outline:
        shadows = [
          Shadow(color: shadowColor, blurRadius: 0, offset: const Offset(1, 1)),
          Shadow(color: shadowColor, blurRadius: 0, offset: const Offset(-1, -1)),
          Shadow(color: shadowColor, blurRadius: 0, offset: const Offset(1, -1)),
          Shadow(color: shadowColor, blurRadius: 0, offset: const Offset(-1, 1)),
        ];
        break;
      case SubtitleEdgeType.raised:
        shadows = [Shadow(color: shadowColor, blurRadius: 2, offset: const Offset(2, 2))];
        break;
      case SubtitleEdgeType.depressed:
        shadows = [Shadow(color: shadowColor, blurRadius: 2, offset: const Offset(-2, -2))];
        break;
      default:
        break;
    }

    return SubtitleViewConfiguration(
      style: TextStyle(
        color: fgColor,
        fontSize: baseFontSize,
        backgroundColor: bgColor,
        shadows: shadows,
      ),
      padding: EdgeInsets.only(
        bottom: (style.bottomPadding ?? 0).toDouble(),
        left: (style.leftPadding ?? 0).toDouble(),
        right: (style.rightPadding ?? 0).toDouble(),
        top: (style.topPadding ?? 0).toDouble(),
      ),
    );
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
          children: [
            // Video fills the entire space with no built-in controls overlay.
            Positioned.fill(
              child: Video(
                controller: widget.controller,
                controls: NoVideoControls,
                subtitleViewConfiguration: _buildSubtitleConfig(_subtitleStyle),
              ),
            ),

            // Buffering indicator.
            StreamBuilder<bool>(
              stream: widget.player.stream.buffering,
              builder: (context, snap) {
                final buffering = snap.data ?? false;
                return buffering
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
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: _ControlsOverlay(
                player: widget.player,
                playlist: widget.playlist,
                initialIndex: widget.initialIndex,
                onBack: widget.onBack,
                onActivity: _onMouseActivity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final media_kit.Player player;
  final List<PlaylistMediaItem> playlist;
  final int initialIndex;
  final VoidCallback onBack;
  final VoidCallback onActivity;

  const _ControlsOverlay({
    required this.player,
    required this.playlist,
    required this.initialIndex,
    required this.onBack,
    required this.onActivity,
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
                  _SeekBar(player: player, onActivity: onActivity),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Play / pause
                      StreamBuilder<bool>(
                        stream: player.stream.playing,
                        builder: (context, snap) {
                          final playing = snap.data ?? player.state.playing;
                          return IconButton(
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              onActivity();
                              playing ? player.pause() : player.play();
                            },
                          );
                        },
                      ),
                      // Position / duration
                      StreamBuilder<Duration>(
                        stream: player.stream.position,
                        builder: (context, snap) {
                          final pos = snap.data ?? player.state.position;
                          final dur = player.state.duration;
                          return Text(
                            '${_fmt(pos)} / ${_fmt(dur)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          );
                        },
                      ),
                      const Spacer(),
                      SubtitleTrackButton(player: player),
                      AudioTrackButton(player: player),
                      // Volume
                      StreamBuilder<double>(
                        stream: player.stream.volume,
                        builder: (context, snap) {
                          final vol = snap.data ?? player.state.volume;
                          return IconButton(
                            icon: Icon(
                              vol == 0
                                  ? Icons.volume_off
                                  : vol < 50
                                      ? Icons.volume_down
                                      : Icons.volume_up,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              onActivity();
                              player.setVolume(vol > 0 ? 0 : 100);
                            },
                          );
                        },
                      ),
                      PlayerMoreMenuButton(
                        player: player,
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
  final media_kit.Player player;
  final VoidCallback onActivity;
  const _SeekBar({required this.player, required this.onActivity});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, posSnap) {
        return StreamBuilder<Duration>(
          stream: widget.player.stream.duration,
          builder: (context, durSnap) {
            final pos = posSnap.data ?? widget.player.state.position;
            final dur = durSnap.data ?? widget.player.state.duration;
            final total = dur.inMilliseconds.toDouble();
            final current = (_dragging ?? pos.inMilliseconds.toDouble()).clamp(0.0, total > 0 ? total : 1.0);

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
                  widget.player.seek(Duration(milliseconds: v.round()));
                  setState(() => _dragging = null);
                },
              ),
            );
          },
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
  final media_kit.Player player;
  const SubtitleTrackButton({required this.player, super.key});

  List<String> _getSubtitleTrackBadges(media_kit.SubtitleTrack track) {
    final List<String> badges = [];
    if (track.language != null && track.language!.isNotEmpty) {
      badges.add(track.language!.toUpperCase());
    }
    final titleLower = (track.title ?? '').toLowerCase();
    if (titleLower.contains('forced')) badges.add('FORCED');
    if (titleLower.contains('sdh')) badges.add('SDH');
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<media_kit.Track>(
      stream: player.stream.track,
      builder: (context, snapshot) {
        final currentTrack = player.state.track.subtitle;
        final hasSubtitles = currentTrack.id != 'no';
        
        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.subtitles,
                color: hasSubtitles ? AppTheme.fullFocusColor : Colors.white,
              ),
              if (hasSubtitles)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppTheme.fullFocusColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            final tracks = player.state.tracks.subtitle;
            showTrackSelectionDialog<media_kit.SubtitleTrack>(
              context: context,
              title: 'Select Subtitles',
              tracks: tracks,
              activeTrack: currentTrack,
              getTrackLabel: (track) {
                if (track.id == 'no') return 'Off';
                if (track.id == 'auto') return 'Auto';
                final lang = track.language ?? '';
                final title = track.title ?? '';
                final label = [title, lang].where((e) => e.isNotEmpty).join(' - ');
                return label.isNotEmpty ? label : 'Track ${track.id}';
              },
              getTrackBadges: _getSubtitleTrackBadges,
              onTrackSelected: (track) {
                player.setSubtitleTrack(track);
              },
            );
          },
        );
      },
    );
  }
}

class AudioTrackButton extends StatelessWidget {
  final media_kit.Player player;
  const AudioTrackButton({required this.player, super.key});

  List<String> _getAudioTrackBadges(media_kit.AudioTrack track) {
    final List<String> badges = [];
    if (track.language != null && track.language!.isNotEmpty) {
      badges.add(track.language!.toUpperCase());
    }
    final titleLower = (track.title ?? '').toLowerCase();
    if (titleLower.contains('5.1')) badges.add('5.1');
    if (titleLower.contains('7.1')) badges.add('7.1');
    if (titleLower.contains('atmos')) badges.add('ATMOS');
    if (titleLower.contains('dolby') || titleLower.contains('ac3') || titleLower.contains('dts')) {
      badges.add('DOLBY');
    }
    if (titleLower.contains('aac')) badges.add('AAC');
    if (titleLower.contains('stereo')) badges.add('STEREO');
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<media_kit.Track>(
      stream: player.stream.track,
      builder: (context, snapshot) {
        final currentTrack = player.state.track.audio;
        final hasMultipleAudio = player.state.tracks.audio.length > 1;

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.audiotrack,
                color: hasMultipleAudio ? AppTheme.fullFocusColor : Colors.white,
              ),
              if (hasMultipleAudio)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppTheme.fullFocusColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            final tracks = player.state.tracks.audio;
            showTrackSelectionDialog<media_kit.AudioTrack>(
              context: context,
              title: 'Select Audio Track',
              tracks: tracks,
              activeTrack: currentTrack,
              getTrackLabel: (track) {
                if (track.id == 'no') return 'Off';
                if (track.id == 'auto') return 'Auto';
                final lang = track.language ?? '';
                final title = track.title ?? '';
                final label = [title, lang].where((e) => e.isNotEmpty).join(' - ');
                return label.isNotEmpty ? label : 'Track ${track.id}';
              },
              getTrackBadges: _getAudioTrackBadges,
              onTrackSelected: (track) {
                player.setAudioTrack(track);
              },
            );
          },
        );
      },
    );
  }
}

class PlayerMoreMenuButton extends StatelessWidget {
  final media_kit.Player player;
  final List<PlaylistMediaItem> playlist;
  final int initialIndex;

  const PlayerMoreMenuButton({
    required this.player,
    required this.playlist,
    required this.initialIndex,
    super.key,
  });

  String _getStreamUrl() {
    try {
      final playlistIndex = player.state.playlist.index;
      if (playlistIndex >= 0 && playlistIndex < playlist.length) {
        return playlist[playlistIndex].url;
      }
    } catch (_) {}
    return playlist.isNotEmpty ? playlist[initialIndex].url : '';
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

/// This file provides the `Media3PreviewPlayer` widget, which is a Flutter widget
/// for displaying a preview of video content using the native Media3 ExoPlayer.
/// It integrates with `Media3PreviewController` to manage the lifecycle and
/// playback of the native video texture.
///
/// The widget handles:
/// - Initializing and disposing of the native player based on its `isActive` state.
/// - Resolving direct links for dynamic URLs.
/// - Managing playback state based on widget visibility and app lifecycle.
/// - Displaying placeholders, error widgets, and the actual video texture.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'media3_preview_controller.dart';

/// A Flutter widget that displays a preview of video content using the native
/// Media3 ExoPlayer.
///
/// This widget provides a highly customizable and performant way to embed
/// video previews, handling their lifecycle, visibility-based playback,
/// and error states.
///
/// Example usage in a list:
/// ```dart
/// Media3PreviewPlayer(
///   url: 'https://example.com/preview.mp4',
///   isActive: isCurrentlyFocused,
///   width: 320,
///   height: 180,
///   borderRadius: BorderRadius.circular(8),
///   placeholder: Image.network('https://example.com/thumb.jpg'),
/// )
/// ```
class Media3PreviewPlayer extends StatefulWidget {
  /// The URL of the media resource to preview. This can be a direct link
  /// or an indirect link that requires resolution via [getDirectLink].
  final String? url;

  /// The URL for a placeholder image shown during loading.
  final String? placeholderImg;

  /// An optional asynchronous callback to obtain a direct, playable media link.
  ///
  /// This is useful for scenarios where the initial [url] is indirect,
  /// temporary, or requires server-side generation. If provided, it will be
  /// called during initialization.
  final Future<String?> Function()? getDirectLink;

  /// Controls whether the preview player should be active and attempt to load/play.
  ///
  /// When `false`, the player's native resources are released and returned
  /// to the pool. This is crucial for performance in lists or grids.
  final bool isActive;

  /// The desired width of the preview player widget.
  final double width;

  /// The desired height of the preview player widget.
  final double height;

  /// The volume of the preview playback.
  ///
  /// Values range from 0.0 (muted) to 1.0 (full volume). Defaults to 0.0.
  final double volume;

  /// Whether the video should start playing automatically once loaded.
  ///
  /// Note that playback also depends on [isActive] and widget visibility.
  /// Defaults to `true`.
  final bool autoPlay;

  /// A widget to display as a placeholder before the video starts playing
  /// or when it's not active.
  ///
  /// If null, a black background is shown.
  final Widget? placeholder;

  /// A widget to display when an error occurs during video loading or playback.
  ///
  /// If null, a default error icon on a black background is shown.
  final Widget? errorWidget;

  /// The initial delay before attempting to initialize the native player.
  ///
  /// This prevents unnecessary resource allocation for items that are quickly
  /// scrolled past. Defaults to 600 milliseconds.
  final Duration initDelay;

  /// How the video should be inscribed into the space allocated during layout.
  ///
  /// Similar to [Image.fit]. Defaults to [BoxFit.contain].
  final BoxFit fit;

  /// Whether the video should loop indefinitely.
  ///
  /// If `true`, the video will restart from the beginning (or [startTimeSeconds])
  /// once it reaches the end. Defaults to `true`.
  final bool isRepeat;

  /// The starting playback position in seconds.
  ///
  /// Used to clip the media and start playback from a specific time.
  final int? startTimeSeconds;

  /// The ending playback position in seconds.
  ///
  /// Used to clip the media and stop/restart playback at a specific time.
  final int? endTimeSeconds;

  /// The border radius to apply to the video preview.
  ///
  /// This is applied using [ClipRRect] around the video texture and overlays.
  final BorderRadiusGeometry? borderRadius;

  /// An optional widget to display on top of the preview.
  ///
  /// This can be used for text overlays, dimming, or custom controls.
  final Widget? child;

  /// Creates a [Media3PreviewPlayer] widget.
  const Media3PreviewPlayer({
    super.key,
    this.url,
    this.placeholderImg,
    this.getDirectLink,
    required this.isActive,
    required this.width,
    required this.height,
    this.volume = 0.0,
    this.autoPlay = true,
    this.placeholder,
    this.errorWidget,
    this.initDelay = const Duration(milliseconds: 600),
    this.fit = BoxFit.contain,
    this.isRepeat = true,
    this.startTimeSeconds,
    this.endTimeSeconds,
    this.borderRadius,
    this.child,
  });

  @override
  State<Media3PreviewPlayer> createState() => _Media3PreviewPlayerState();
}

/// The state for the [Media3PreviewPlayer] widget.
class _Media3PreviewPlayerState extends State<Media3PreviewPlayer>
    with WidgetsBindingObserver {
  /// The controller for the native Media3 preview player.
  Media3PreviewController? _controller;

  /// Indicates if the widget is currently visible on screen.
  bool _isCurrentlyVisible = false;

  /// Indicates if the video is currently playing.
  bool _isPlaying = false;

  /// Indicates if an error has occurred during playback.
  bool _hasError = false;

  /// A flag to track if the first video frame has been rendered.
  bool _hasRenderedFirstFrame = false;

  /// The current application lifecycle state.
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  /// Timer for scheduling delayed initialization.
  Timer? _initTimer;

  /// Subscription for listening to error events from the controller.
  StreamSubscription? _errorSubscription;

  /// Subscription for listening to playback started events from the controller.
  StreamSubscription? _playbackStartedSubscription;

  /// Counter to ensure only the latest initialization attempt is valid.
  int _initCounter = 0;

  /// Stores the last sent play state to avoid redundant commands to the native player.
  bool? _lastSentPlayState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.isActive) {
      _scheduleInit();
    }
  }

  @override
  void didUpdateWidget(covariant Media3PreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _scheduleInit();
      } else {
        _disposeController();
      }
      return;
    }

    if (oldWidget.url != widget.url ||
        oldWidget.getDirectLink != widget.getDirectLink) {
      _reinit();
      return;
    }

    if (_controller != null && oldWidget.isRepeat != widget.isRepeat) {
      _controller!.setLooping(widget.isRepeat);
    }

    _updatePlaybackState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _updatePlaybackState();
  }

  /// Schedules a delayed initialization of the native player.
  ///
  /// This prevents immediate resource allocation if the widget is quickly
  /// scrolled out of view.
  void _scheduleInit() {
    if (_controller != null) return;

    _initTimer?.cancel();
    _initTimer = Timer(widget.initDelay, _init);
  }

  /// Reinitializes the native player by disposing the current one and
  /// scheduling a new initialization if the widget is active.
  Future<void> _reinit() async {
    _disposeController();
    if (widget.isActive) {
      _scheduleInit();
    }
  }

  /// Initializes the native player controller, loads the media, and sets up
  /// necessary subscriptions.
  ///
  /// This method is designed to handle potential race conditions by using
  /// `_initCounter` to ensure only the latest initialization attempt proceeds.
  Future<void> _init() async {
    final int initId = ++_initCounter;

    try {
      String? finalUrl = widget.url;
      if (widget.getDirectLink != null) {
        final direct = await widget.getDirectLink!();
        if (initId != _initCounter) return;
        finalUrl = direct;
      }

      if (finalUrl == null) {
        // If no URL is available (url is null and getDirectLink returns null),
        // we stay in the placeholder state.
        return;
      }

      final controller = await Media3PreviewController.create();
      if (initId != _initCounter) {
        controller.dispose();
        return;
      }

      await controller.loadUrl(
        finalUrl,
        width: widget.width.toInt(),
        height: widget.height.toInt(),
        volume: widget.volume,
        autoPlay: widget.autoPlay,
        isRepeat: widget.isRepeat,
        startTimeSeconds: widget.startTimeSeconds,
        endTimeSeconds: widget.endTimeSeconds,
      );

      if (!mounted || initId != _initCounter) {
        controller.dispose();
        return;
      }

      _errorSubscription = controller.errors.listen((_) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _isPlaying = false;
          _hasRenderedFirstFrame = false; // Reset on error
          _lastSentPlayState = null;
        });
      });

      _playbackStartedSubscription = controller.playbackStarted.listen((_) {
        if (!mounted) return;
        setState(() {
          _hasRenderedFirstFrame = true; // Set flag on first frame
        });
      });

      setState(() {
        _controller = controller;
        _hasError = false;
        _hasRenderedFirstFrame = false; // Reset on new controller
      });

      _updatePlaybackState();
    } catch (_) {
      if (mounted && initId == _initCounter) {
        setState(() {
          _hasError = true;
          _hasRenderedFirstFrame = false;
        });
      }
    }
  }

  /// Updates the playback state of the native player based on widget activity,
  /// visibility, app lifecycle, and error status.
  ///
  /// This method ensures the player only plays when all conditions are met.
  void _updatePlaybackState() async {
    if (_controller == null) return;

    final bool shouldPlay =
        widget.isActive &&
        _isCurrentlyVisible &&
        _lifecycleState == AppLifecycleState.resumed &&
        widget.autoPlay &&
        !_hasError;

    if (_isPlaying != shouldPlay) {
      setState(() => _isPlaying = shouldPlay);
    }

    if (_lastSentPlayState == shouldPlay) return;
    _lastSentPlayState = shouldPlay;

    if (shouldPlay) {
      await _controller!.play();
    } else {
      await _controller!.pause();
    }
  }

  /// Disposes of the native player controller and cancels all subscriptions.
  ///
  /// Resets all internal state flags related to playback and errors.
  void _disposeController() {
    _initTimer?.cancel();
    _errorSubscription?.cancel();
    _playbackStartedSubscription?.cancel(); // Unsubscribe

    _controller?.dispose();
    _controller = null;

    _isPlaying = false;
    _hasError = false;
    _hasRenderedFirstFrame = false; // Reset flag
    _lastSentPlayState = null;
  }

  /// Callback for [VisibilityDetector] to update the widget's visibility state.
  ///
  /// This method is triggered when the widget's visibility changes, and it
  /// updates the internal `_isCurrentlyVisible` flag, triggering a playback state update.
  ///
  /// [info]: Contains information about the widget's visibility.
  void _onVisibilityChanged(VisibilityInfo info) {
    final bool visible = info.visibleFraction > 0.1;
    if (_isCurrentlyVisible == visible) return;

    _isCurrentlyVisible = visible;
    _updatePlaybackState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('preview_${widget.url}_${_controller?.textureId}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _PreviewTexture(
                controller: _controller,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                hasError: _hasError,
                hasRenderedFirstFrame: _hasRenderedFirstFrame, // Pass flag
              ),
              _PreviewOverlay(
                placeholderImg: widget.placeholderImg,
                isPlaying: _isPlaying,
                hasError: _hasError,
                hasController: _controller != null,
                hasRenderedFirstFrame: _hasRenderedFirstFrame, // Pass flag
                placeholder: widget.placeholder,
                errorWidget: widget.errorWidget,
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        ),
      ),
    );
  }
}

/// A widget that renders the native video texture for the preview player.
///
/// It displays the video content provided by the [controller] as a [Texture]
/// within the specified [width] and [height]. It respects the [fit] property
/// for scaling the video and conditionally hides itself on [hasError] or
/// before the [hasRenderedFirstFrame].
class _PreviewTexture extends StatelessWidget {
  /// The controller for the native Media3 preview player, providing the texture ID.
  final Media3PreviewController? controller;

  /// The width of the texture widget.
  final double width;

  /// The height of the texture widget.
  final double height;

  /// How the video should be inscribed into the space allocated during layout.
  final BoxFit fit;

  /// Indicates if an error has occurred during playback, preventing texture display.
  final bool hasError;

  /// A flag indicating if the first video frame has been rendered by the native player.
  /// The texture is only shown after the first frame has rendered.
  final bool hasRenderedFirstFrame;

  /// Creates a [_PreviewTexture] widget.
  const _PreviewTexture({
    required this.controller,
    required this.width,
    required this.height,
    required this.fit,
    required this.hasError,
    required this.hasRenderedFirstFrame,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null || hasError || !hasRenderedFirstFrame) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: FittedBox(
        fit: fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: width,
          height: height,
          child: ExcludeSemantics(
            child: Texture(
              key: ValueKey('texture_${controller!.textureId}'),
              textureId: controller!.textureId,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

/// A widget that displays an overlay on top of the video texture,
/// showing placeholder, error, or nothing based on playback state and error status.
///
/// It uses an [IndexedStack] to switch between three states:
/// 0: No overlay (when video is playing and rendered).
/// 1: [placeholder] (when video is not playing or not yet rendered).
/// 2: [errorWidget] (when an error has occurred).
class _PreviewOverlay extends StatelessWidget {
  /// The URL for a placeholder image shown during loading.
  final String? placeholderImg;

  /// Indicates if the video is currently playing.
  final bool isPlaying;

  /// Indicates if an error has occurred during playback.
  final bool hasError;

  /// Indicates if a [Media3PreviewController] is available and initialized.
  final bool hasController;

  /// A flag indicating if the first video frame has been rendered by the native player.
  /// The overlay state changes once the first frame is rendered.
  final bool hasRenderedFirstFrame;

  /// The widget to display as a placeholder when the video is not active or loading.
  final Widget? placeholder;

  /// The widget to display when an error occurs during video playback.
  final Widget? errorWidget;

  /// Creates a [_PreviewOverlay] widget.
  const _PreviewOverlay({
    required this.placeholderImg,
    required this.isPlaying,
    required this.hasError,
    required this.hasController,
    required this.hasRenderedFirstFrame,
    this.placeholder,
    this.errorWidget,
  });

  /// Determines the index of the child to show in the [IndexedStack].
  /// - 0: No overlay (video is playing and rendered).
  /// - 1: Placeholder (video is not playing or not yet rendered).
  /// - 2: Error widget (an error has occurred).
  int get _index {
    if (hasError) return 2;
    if (isPlaying && hasController && hasRenderedFirstFrame) return 0;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: IndexedStack(
        index: _index,
        children: [
          const SizedBox.shrink(), // Nothing when video is playing
          SizedBox.expand(
            child:
                placeholder ??
                (placeholderImg != null
                    ? Image.network(
                      placeholderImg!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, _, _) => Container(color: Colors.grey[900]),
                    )
                    : const ColoredBox(color: Colors.black)),
          ),
          SizedBox.expand(
            child:
                errorWidget ??
                const ColoredBox(
                  color: Colors.black,
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

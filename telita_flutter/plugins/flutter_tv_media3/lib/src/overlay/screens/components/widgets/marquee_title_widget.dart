import 'package:flutter/material.dart';
import 'dart:async';

class MarqueeWidget extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool focus;

  const MarqueeWidget({
    super.key,
    required this.text,
    this.style,
    required this.focus,
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateMarquee();
      }
    });
  }

  @override
  void didUpdateWidget(MarqueeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focus != oldWidget.focus || widget.text != oldWidget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateMarquee();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateMarquee() {
    _timer?.cancel();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }

    if (widget.focus && _isTextOverflowing()) {
      _startMarquee();
    }
  }

  bool _isTextOverflowing() {
    if (!mounted) return false;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return false;
    }

    final double maxWidth = renderBox.size.width;
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    return textPainter.size.width > maxWidth;
  }

  void _startMarquee() {
    _timer?.cancel();
    if (!mounted || !widget.focus) return;

    const Duration initialPause = Duration(seconds: 2);
    const Duration endPause = Duration(seconds: 2);
    const double scrollSpeed = 60.0;

    void scroll() {
      if (!mounted || !_scrollController.hasClients) return;
      final double maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final Duration scrollDuration = Duration(
        milliseconds: (maxScroll / scrollSpeed * 1000).round(),
      );

      _timer = Timer(initialPause, () {
        if (!mounted || !widget.focus || !_scrollController.hasClients) return;

        _scrollController
            .animateTo(
              maxScroll,
              duration: scrollDuration,
              curve: Curves.linear,
            )
            .then((_) {
              if (!mounted || !widget.focus) return;
              _timer = Timer(endPause, () {
                if (!mounted ||
                    !widget.focus ||
                    !_scrollController.hasClients) {
                  return;
                }

                _scrollController.jumpTo(0.0);
                scroll();
              });
            });
      });
    }

    scroll();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }
}

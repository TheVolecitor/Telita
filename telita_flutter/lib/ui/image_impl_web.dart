// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;

class WebSafeImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final int? memCacheWidth;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  const WebSafeImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.memCacheWidth,
    this.errorWidget,
  });

  @override
  State<WebSafeImage> createState() => _WebSafeImageState();
}

class _WebSafeImageState extends State<WebSafeImage> {
  late String _viewId;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'html-img-${DateTime.now().microsecondsSinceEpoch}-${widget.imageUrl.hashCode}';
    
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final img = html.ImageElement()
        ..src = widget.imageUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.margin = '0'
        ..style.padding = '0'
        ..style.objectFit = _getFitString(widget.fit);
        
      img.onError.listen((e) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
        
      return img;
    });
  }

  String _getFitString(BoxFit? fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'cover';
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
      default:
        return 'cover';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && widget.errorWidget != null) {
      return widget.errorWidget!(context, widget.imageUrl, Exception('Image failed to load'));
    }
    
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

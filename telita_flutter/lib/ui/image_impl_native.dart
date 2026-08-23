import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class WebSafeImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      memCacheWidth: memCacheWidth,
      errorWidget: errorWidget,
    );
  }
}

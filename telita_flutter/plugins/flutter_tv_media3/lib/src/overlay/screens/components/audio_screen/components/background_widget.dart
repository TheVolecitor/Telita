import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

class BackgroundWidget extends StatelessWidget {
  final String? placeholderImg;
  final String? artworkUrl;
  final Uint8List? artworkData;

  const BackgroundWidget({
    super.key,
    this.placeholderImg,
    this.artworkUrl,
    this.artworkData,
  });

  @override
  Widget build(BuildContext context) {
    Widget backgroundImage;
    if (placeholderImg != null) {
      backgroundImage = Image.network(
        placeholderImg!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const SizedBox.shrink(),
      );
    } else if (artworkUrl != null) {
      backgroundImage = Image.network(
        artworkUrl!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const SizedBox.shrink(),
      );
    } else if (artworkData != null) {
      backgroundImage = Image.memory(artworkData!, fit: BoxFit.cover);
    } else {
      backgroundImage = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E3142), Color(0xFF1B1C25)],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        backgroundImage,
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(color: Colors.black.withValues(alpha: 0.4)),
        ),
      ],
    );
  }
}

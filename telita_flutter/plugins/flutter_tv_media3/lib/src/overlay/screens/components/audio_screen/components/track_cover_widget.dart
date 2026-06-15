import 'package:flutter/material.dart';

class TrackCoverWidget extends StatelessWidget {
  const TrackCoverWidget({super.key, required this.image});

  final DecorationImage? image;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[850],
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
              image: image,
            ),
            child: image != null ? null : Icon(Icons.music_note, size: 140),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Register fvp as the backend for video_player
  fvp.registerWith(); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyVideoScreen(),
    );
  }
}

class MyVideoScreen extends StatefulWidget {
  const MyVideoScreen({super.key});

  @override
  State<MyVideoScreen> createState() => _MyVideoScreenState();
}

class _MyVideoScreenState extends State<MyVideoScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Using the same 4K HDR HEVC URL
    _controller = VideoPlayerController.networkUrl(Uri.parse(
        'https://aiostreamsfortheweebs.midnightignite.me/api/v1/debrid/playback/eyJpIjoiN0tJNVRxR1dBSlRFOFk1aFpUSHJWQT09IiwiZSI6Ing5OGpHQjFmTE11K3M2VndKbXY0RnRFQzROVGRXeU9RRVhneHNFaXlJTEh0aXhmZzdsKzUwRDJYSTY3Q3ViZ1R0MjVKMDhYWGpIMEVYendjZlFKM2JnSHJyYTBaZDMxeTYyOW8wUEtQczRBPSIsInQiOiJhIn0/eyJ0eXBlIjoidG9ycmVudCIsInRpdGxlIjoiSWwgQ2F2YWxpZXJlIG9zY3VybyAtIFRoZSBEYXJrIEtuaWdodCAoMjAwNS0yMDEyKSBJTUFYIDIxNjBwIEgyNjUgSERSMTAgSVRBLkVORyBzdWIgTlVpdGEuZW5nIFNwMzNkeTk0LU1JUkNyZXciLCJoYXNoIjoiYThkOGY2N2NkNTM1ZGNiY2NiZmNlYWYxODJhNjhjMWE5MTBmZjMwZSIsInNvdXJjZXMiOltdLCJpbmRleCI6MiwiY2FjaGVBbmRQbGF5IjpmYWxzZSwiYXV0b1JlbW92ZURvd25sb2FkcyI6ZmFsc2V9/c72d0b833df0c1c836644c2fdb922221efc0a027501dc82a7be5e22381a888ab/Batman%20Begins%20(2005)%20ITA.ENG%202160p%20H265%20HDR10%20sub%20NUita.eng%20Sp33dy94-MIRCrew.mkv'))
      ..initialize().then((_) {
        // Ensure the first frame is shown and play
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

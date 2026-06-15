import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_tv_media3/flutter_tv_media3.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media3 Preview Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PreviewDemoScreen(),
    );
  }
}

class PreviewDemoScreen extends StatefulWidget {
  const PreviewDemoScreen({super.key});

  @override
  State<PreviewDemoScreen> createState() => _PreviewDemoScreenState();
}

class _PreviewDemoScreenState extends State<PreviewDemoScreen> {
  final playerController = FtvMedia3PlayerController();

  final List<PlaylistMediaItem> items = [
    // === VIDEO EXAMPLES ===

    // Basic video - minimal configuration
    PlaylistMediaItem(
      id: 'video_basic_001',
      url:
          'https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4',
      title: 'Big Buck Bunny (Basic)',
      mediaItemType: MediaItemType.video,
      placeholderImg:
          'https://peach.blender.org/wp-content/uploads/title_anouncement.jpg',
      media3PreviewConfig: const Media3PreviewConfig(
        url:
            'https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4',
        width: 320,
        height: 180,
        autoPlay: true,
        volume: 0.0,
      ),
    ),

    // Clipped video segment (10s to 20s)
    PlaylistMediaItem(
      id: 'video_clipped_002',
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      title: 'Elephants Dream (Clipped 10-20s)',
      mediaItemType: MediaItemType.video,
      placeholderImg: 'https://i.ytimg.com/vi/kPdv44HtEoA/maxresdefault.jpg',
      media3PreviewConfig: const Media3PreviewConfig(
        startTimeSeconds: 10,
        endTimeSeconds: 20,
        isRepeat: true,
        volume: 0.0,
      ),
    ),

    // Video with all metadata and watch time saving
    PlaylistMediaItem(
      id: 'video_full_003',
      url:
          'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
      label: 'HLS 1080p',
      title: 'Tears of Steel',
      subTitle: 'Sci-Fi Short Film',
      description:
          'A group of warriors and scientists gather at the Oude Kerk in Amsterdam to stage a crucial event from the past, in a desperate attempt to save the world from destructive robots.',
      mediaItemType: MediaItemType.video,
      duration: 734,
      startPosition: 120,
      placeholderImg:
          'https://media.themoviedb.org/t/p/w1066_and_h600_bestv2/msqeiEyIRpPAtrCeRGFNZQ9tkJL.jpg',
      coverImg:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/Tears_of_Steel_frame.png/640px-Tears_of_Steel_frame.png',
      updateWatchTime: true,
      saveWatchTime: ({
        required String id,
        required int duration,
        required int position,
        required int playIndex,
      }) async {
        debugPrint(
          'SAVE WATCH TIME: id=$id, duration=$duration, position=$position, playIndex=$playIndex',
        );
      },
      media3PreviewConfig: Media3PreviewConfig(
        width: 640,
        height: 360,
        autoPlay: true,
        volume: 0.0,
        isRepeat: true,
        startTimeSeconds: 30,
        endTimeSeconds: 60,
        placeholderImg:
            'https://media.themoviedb.org/t/p/w1066_and_h600_bestv2/msqeiEyIRpPAtrCeRGFNZQ9tkJL.jpg',
      ),
    ),

    // Video with external subtitles and audio tracks
    PlaylistMediaItem(
      id: 'video_tracks_004',
      url:
          'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
      title: 'Sintel (with Subtitles & Audio)',
      subTitle: 'External Tracks Example',
      description: 'Girl searching for a baby dragon.',
      mediaItemType: MediaItemType.video,
      duration: 888,
      startPosition: 60,
      placeholderImg:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Sintel_poster.jpg/636px-Sintel_poster.jpg',
      coverImg:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Sintel_poster.jpg/636px-Sintel_poster.jpg',
      headers: {'Referer': 'https://example.com/player'},
      subtitles: [
        MediaItemSubtitle(
          url:
              'https://raw.githubusercontent.com/mtoczko/hls-test-streams/refs/heads/master/test-vtt/text/1.vtt',
          language: 'en',
          label: 'English',
          mimeType: 'text/vtt',
        ),
        MediaItemSubtitle(
          url:
              'https://raw.githubusercontent.com/mtoczko/hls-test-streams/refs/heads/master/test-vtt/text/2.vtt',
          language: 'de',
          label: 'Deutsch',
          mimeType: 'text/vtt',
        ),
      ],
      audioTracks: [
        MediaItemAudioTrack(
          url: 'https://download.samplelib.com/mp3/sample-15s.mp3',
          language: 'en',
          label: 'English 5.1',
          mimeType: 'audio/mpeg',
        ),
        MediaItemAudioTrack(
          url: 'https://download.samplelib.com/mp3/sample-12s.mp3',
          language: 'de',
          label: 'German Stereo',
          mimeType: 'audio/mpeg',
        ),
      ],
      saveWatchTime: ({
        required String id,
        required int duration,
        required int position,
        required int playIndex,
      }) async {
        debugPrint(
          'SAVE WATCH TIME: id=$id, duration=$duration, position=$position, playIndex=$playIndex',
        );
      },
    ),

    // Video with multiple quality options (resolutions)
    PlaylistMediaItem(
      id: 'video_res_005',
      url:
          'https://www.sample-videos.com/video321/mp4/360/big_buck_bunny_360p_30mb.mp4',
      label: 'Multi-Quality',
      title: 'Big Buck Bunny (Resolutions)',
      mediaItemType: MediaItemType.video,
      userAgent: 'MyApp/1.0 (Flutter)',
      placeholderImg:
          'https://peach.blender.org/wp-content/uploads/title_anouncement.jpg',
      resolutions: {
        '1080p':
            'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        '720p':
            'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        '360p':
            'https://avtshare01.rz.tu-ilmenau.de/avt-vqdb-uhd-1/test_1/segments/bigbuck_bunny_8bit_200kbps_360p_60.0fps_h264.mp4',
      },
      saveWatchTime: ({
        required String id,
        required int duration,
        required int position,
        required int playIndex,
      }) async {
        debugPrint(
          'SAVE WATCH TIME: id=$id, duration=$duration, position=$position, playIndex=$playIndex',
        );
      },
    ),

    // Video with dynamic link resolution (success)
    PlaylistMediaItem(
      id: 'video_dynamic_006',
      url: 'myapp://resolve/video/success',
      title: 'Dynamic Link (Success)',
      mediaItemType: MediaItemType.video,
      placeholderImg: 'https://cdn-icons-png.flaticon.com/512/2926/2926319.png',
      saveWatchTime: ({
        required String id,
        required int duration,
        required int position,
        required int playIndex,
      }) async {
        debugPrint(
          'SAVE WATCH TIME: id=$id, duration=$duration, position=$position, playIndex=$playIndex',
        );
      },
      getDirectLink: ({
        required PlaylistMediaItem item,
        Function({
          required String state,
          double? progress,
          required int requestId,
        })?
        onProgress,
        required int requestId,
      }) async {
        // Simulating resolution with progress updates
        for (int i = 1; i <= 5; i++) {
          onProgress?.call(
            requestId: requestId,
            state: 'Resolving... ($i/5)',
            progress: i / 5,
          );
          await Future.delayed(const Duration(milliseconds: 400));
        }
        return item.copyWith(
          url:
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        );
      },
      media3PreviewConfig: Media3PreviewConfig(
        getPreviewDirectLink: () async {
          await Future.delayed(const Duration(seconds: 1));
          return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
        },
      ),
    ),

    // Video with dynamic link resolution (error)
    PlaylistMediaItem(
      id: 'video_dynamic_error_007',
      url: 'myapp://resolve/video/error',
      title: 'Dynamic Link (Error)',
      mediaItemType: MediaItemType.video,
      placeholderImg: 'https://cdn-icons-png.flaticon.com/512/5853/5853981.png',
      saveWatchTime: ({
        required String id,
        required int duration,
        required int position,
        required int playIndex,
      }) async {
        debugPrint(
          'SAVE WATCH TIME: id=$id, duration=$duration, position=$position, playIndex=$playIndex',
        );
      },
      getDirectLink: ({
        required PlaylistMediaItem item,
        Function({
          required String state,
          double? progress,
          required int requestId,
        })?
        onProgress,
        required int requestId,
      }) async {
        await Future.delayed(const Duration(milliseconds: 500));
        throw Exception('API Error: Failed to resolve video URL');
      },
    ),

    // Video with broken URL (error handling test)
    PlaylistMediaItem(
      id: 'video_broken_008',
      url: 'https://invalid-url-that-will-fail.com/video.mp4',
      title: 'Broken Link (Error Handling)',
      mediaItemType: MediaItemType.video,
      placeholderImg:
          'https://www.elegantthemes.com/blog/wp-content/uploads/2021/11/broken-links-featured.png',
    ),

    // === AUDIO EXAMPLES ===

    // Music track with full metadata
    PlaylistMediaItem(
      id: 'audio_001',
      url: 'https://download.samplelib.com/mp3/sample-15s.mp3',
      title: 'Sample Audio Track',
      subTitle: 'MP3 15 seconds',
      description: 'Sample audio file for testing audio playback',
      artistName: 'Sample Artist',
      trackName: 'Demo Track',
      albumName: 'Test Album',
      albumYear: '2024',
      mediaItemType: MediaItemType.audio,
      duration: 15,
      coverImg:
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&auto=format&fit=crop',
      placeholderImg:
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&auto=format&fit=crop',
      updateWatchTime: false,
    ),

    // === TV STREAM EXAMPLES ===

    // Live TV channel with HLS stream
    PlaylistMediaItem(
      id: 'tv_001',
      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      label: 'Live',
      title: 'Test Live Stream',
      subTitle: 'HLS Live TV',
      description: 'Test live TV stream - no watch time saved for live content',
      mediaItemType: MediaItemType.tvStream,
      placeholderImg: 'https://cdn-icons-png.flaticon.com/512/2964/2964514.png',
      updateWatchTime: false,
      programs: [
        //EPG programs would be loaded here
        EpgProgram(
          title: 'News Hour',
          description: 'Daily news coverage',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(Duration(hours: 1)),
        ),
      ],
    ),

    // === SPECIAL FORMATS ===

    // VP9/WebM video codec test
    PlaylistMediaItem(
      id: 'video_vp9_009',
      url:
          'https://test-videos.co.uk/vids/bigbuckbunny/webm/vp9/1080/Big_Buck_Bunny_1080_10s_1MB.webm',
      title: 'VP9 Codec Test',
      subTitle: 'WebM/VP9 format',
      mediaItemType: MediaItemType.video,
      placeholderImg:
          'https://peach.blender.org/wp-content/uploads/title_anouncement.jpg',
      media3PreviewConfig: const Media3PreviewConfig(
        volume: 0.0,
        autoPlay: true,
      ),
    ),
  ];
  int _selectedIndex = 0;
  double _volume = 0.0;
  bool _isRepeat = true;
  StreamSubscription? _playerStateSubscription;
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _focusNodes = [];

  void _initFocusNodes() {
    for (var i = 0; i < items.length; i++) {
      _focusNodes.add(FocusNode());
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemWidth = 260.0; // approximate width including padding
    _scrollController.animateTo(
      index * itemWidth,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _initFocusNodes();

    // Synchronize selected index with player's current item
    _playerStateSubscription = playerController.playerStateStream.listen((
      state,
    ) {
      if (state.playIndex != _selectedIndex &&
          state.playIndex >= 0 &&
          state.playIndex < items.length) {
        if (mounted) {
          setState(() {
            _selectedIndex = state.playIndex;
          });
          // Ensure focus and scroll follow the new index
          _focusNodes[_selectedIndex].requestFocus();
          _scrollToIndex(_selectedIndex);
        }
      }
    });

    // Initialize controller with some default settings
    playerController.setConfig(
      onScreenshotTaken: ({
        required Uint8List bytes,
        required PlaylistMediaItem item,
      }) async {
        debugPrint(bytes.toString());
        debugPrint(item.title);
      },
      playerSettings: PlayerSettings(
        videoQuality: VideoQuality.high,
        isAfrEnabled: true,
      ),
      // Trigger pagination when 2 items are left in the playlist
      paginationThreshold: 6,
      onLoadMore: () async {
        debugPrint('PAGINATION: Loading more items...');

        // Simulate network delay
        await Future.delayed(const Duration(seconds: 2));

        final nextId = items.length + 1;
        final List<PlaylistMediaItem> newItems = [
          PlaylistMediaItem(
            id: '$nextId',
            title: 'Pagination Item $nextId',
            url:
                'https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4',
            coverImg:
                'https://habrastorage.org/getpro/habr/olpictures/d27/d54/495/d27d54495a66c5047fa9929b937fc786.jpg',
          ),
          PlaylistMediaItem(
            id: '${nextId + 1}',
            title: 'Pagination Item ${nextId + 1}',
            url:
                'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
            coverImg: 'https://i.ytimg.com/vi/kPdv44HtEoA/maxresdefault.jpg',
          ),
        ];

        // Update local state
        setState(() {
          items.addAll(newItems);
          for (var i = 0; i < newItems.length; i++) {
            _focusNodes.add(FocusNode());
          }
        });

        debugPrint('PAGINATION: Returning ${newItems.length} items.');
        return newItems;
      },
    );
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _scrollController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    playerController.close();
    super.dispose();
  }

  void _openFullPlayer(int index) {
    playerController.openPlayer(
      context: context,
      playlist: items,
      initialIndex: index,
    );
  }

  Future<void> _showThumbnail(PlaylistMediaItem item) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text('Thumbnail: ${item.title}'),
            content: FutureBuilder<Uint8List?>(
              future: playerController.getVideoThumbnail(
                item.url,
                timeInSeconds: 15,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return const Text('Failed to generate thumbnail');
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(snapshot.data!),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          ),
    );
  }

  Future<void> _showMetadata(PlaylistMediaItem item) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text('Metadata: ${item.title}'),
            content: SizedBox(
              width: 500,
              child: FutureBuilder<Map<String, dynamic>?>(
                future: playerController.getMediaMetadata(item.url),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: Image.asset('assets/loading.gif', width: 60, height: 60, color: Colors.white70, colorBlendMode: BlendMode.srcIn)),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return const Text('No metadata available');
                  }
                  final metadata = snapshot.data!;
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          metadata.entries
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text('${e.key}: ${e.value}'),
                                ),
                              )
                              .toList(),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = items[_selectedIndex];

    return Scaffold(
      body: Stack(
        children: [
          // Background "Hero" Preview
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Media3PreviewPlayer(
                key: ValueKey('hero_${selectedItem.id}'),
                url: selectedItem.url,
                isActive: true,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                volume: _volume,
                fit: BoxFit.cover,
                isRepeat: _isRepeat,
                startTimeSeconds:
                    selectedItem.media3PreviewConfig?.startTimeSeconds,
                endTimeSeconds:
                    selectedItem.media3PreviewConfig?.endTimeSeconds,
                getDirectLink:
                    selectedItem.media3PreviewConfig?.getPreviewDirectLink,
                placeholder: Image.network(
                  selectedItem.placeholderImg ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.black),
                ),
                errorWidget: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load: ${selectedItem.title}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Check URL or network connection',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Gradient Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // UI Elements
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 24.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEDIA3 PREVIEW',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NATIVE TEXTURE RENDERING',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ), // Replaced Spacer with fixed gap
                    // Item Title and Description
                    Text(
                      selectedItem.title ?? selectedItem.label ?? 'n/a',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 600,
                      child: Text(
                        'This preview is rendered directly onto a Flutter Texture using native Media3 ExoPlayer. '
                        'It supports clipping, volume control, and background loading without blocking the UI thread.',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Controls section
                    Wrap(
                      spacing: 16.0,
                      runSpacing: 16.0,
                      children: [
                        _ControlButton(
                          icon:
                              _volume > 0 ? Icons.volume_up : Icons.volume_off,
                          label: 'VOLUME: ${(_volume * 100).toInt()}%',
                          onPressed: () {
                            setState(() {
                              _volume = _volume == 0 ? 1.0 : 0.0;
                            });
                          },
                        ),
                        _ControlButton(
                          icon: _isRepeat ? Icons.repeat : Icons.repeat_one,
                          label: _isRepeat ? 'LOOP: ON' : 'LOOP: OFF',
                          onPressed: () {
                            setState(() {
                              _isRepeat = !_isRepeat;
                            });
                          },
                        ),
                        _ControlButton(
                          icon: Icons.play_arrow,
                          label: 'WATCH FULL',
                          isPrimary: true,
                          onPressed: () => _openFullPlayer(_selectedIndex),
                        ),
                        _ControlButton(
                          icon: Icons.camera_alt_outlined,
                          label: 'SCREENSHOT',
                          onPressed: () => _showThumbnail(selectedItem),
                        ),
                        _ControlButton(
                          icon: Icons.analytics_outlined,
                          label: 'METADATA',
                          onPressed: () => _showMetadata(selectedItem),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Horizontal List of items
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _PreviewCard(
                            item: items[index],
                            isSelected: _selectedIndex == index,
                            focusNode: _focusNodes[index],
                            onFocus: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            onTap: () => _openFullPlayer(index),
                          );
                        },
                      ),
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
}

class _PreviewCard extends StatelessWidget {
  final PlaylistMediaItem item;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  const _PreviewCard({
    required this.item,
    required this.isSelected,
    required this.focusNode,
    required this.onFocus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20.0),
      child: Focus(
        focusNode: focusNode,
        onFocusChange: (hasFocus) {
          if (hasFocus) onFocus();
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final isEnter =
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA;
            if (isEnter) {
              onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: hasFocus ? 280 : 240,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasFocus ? Colors.white : Colors.white24,
                    width: hasFocus ? 4 : 1,
                  ),
                  boxShadow:
                      hasFocus
                          ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ]
                          : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Mini Preview inside the card
                      Media3PreviewPlayer(
                        url: item.media3PreviewConfig?.url,
                        isActive: hasFocus, // Only plays if focused
                        width: 280,
                        height: 180,
                        volume: 0,
                        fit: BoxFit.cover,
                        initDelay: const Duration(milliseconds: 400),
                        startTimeSeconds:
                            item.media3PreviewConfig?.startTimeSeconds,
                        endTimeSeconds:
                            item.media3PreviewConfig?.endTimeSeconds,
                        getDirectLink:
                            item.media3PreviewConfig?.getPreviewDirectLink,
                        placeholder: Image.network(
                          item.placeholderImg ?? '',
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  Container(color: Colors.grey[900]),
                        ),
                        //borderRadius: BorderRadius.circular(16),
                      ),
                      // Focus highlight overlay
                      if (!hasFocus)
                        Positioned.fill(
                          child: Container(color: Colors.black26),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Text(
                            item.title ?? item.label ?? 'n/a',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  hasFocus
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              fontSize: hasFocus ? 16 : 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isPrimary ? Colors.blue : Colors.white.withValues(alpha: 0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'core/skip_segment_client.dart';

import 'ui/sidebar.dart';
import 'ui/auth_screen.dart';
import 'ui/profile_select_screen.dart';
import 'ui/discover_screen.dart';
import 'ui/addon_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/detail_screen.dart';
import 'ui/downloads_screen.dart';
import 'core/auth.dart';
import 'core/addon_client.dart';
import 'core/watch_history.dart';
import 'core/settings.dart';
import 'core/simkl_client.dart';
import 'ui/splash_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'dart:ui' show ImageFilter;
import 'player_registry_stub.dart'
    if (dart.library.html) 'player_registry_stub.dart'
    if (dart.library.io) 'player_registry_native.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        // Change 8888 to your proxy's port (Fiddler/Charles default is 8888, Proxyman is 9090)
        return "PROXY 127.0.0.1:8000; DIRECT";
      }
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Register fvp conditionally ONCE at startup with correct lowercase decoder names.
  // Must be called before any VideoPlayerController is created.
  registerVideoPlayerBackend();

  // Aggressively limit the global ImageCache size to keep RAM usage low.
  // The default is 1000 images or 100MB. We'll drop it to 200 images or 50MB.
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();
      final prefs = await SharedPreferences.getInstance();

      final width = prefs.getDouble('window_width') ?? 1280.0;
      final height = prefs.getDouble('window_height') ?? 720.0;
      final x = prefs.getDouble('window_x');
      final y = prefs.getDouble('window_y');
      final isMaximized = prefs.getBool('window_maximized') ?? false;

      WindowOptions windowOptions = WindowOptions(
        size: Size(width, height),
        center: x == null || y == null,
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (x != null && y != null) {
          await windowManager.setPosition(Offset(x, y));
        }
        await windowManager.show();
        if (isMaximized) {
          await windowManager.maximize();
        }
        await windowManager.focus();
      });
    } catch (e) {
      print('WindowManager error: $e');
    }
    try {
      String executable;
      if (Platform.isMacOS) {
        executable = p.join(
          p.dirname(Platform.resolvedExecutable),
          '..',
          'Resources',
          'libcore',
        );
      } else {
        executable = Platform.isWindows ? 'libcore.exe' : './libcore';
      }

      final coreProcess = await Process.start(executable, []);
      print('[CORE] $executable started with PID: ${coreProcess.pid}');

      coreProcess.stdout.transform(utf8.decoder).listen((data) {
        print('[CORE-OUT] ${data.trim()}');
      });
      coreProcess.stderr.transform(utf8.decoder).listen((data) {
        print('[CORE-ERR] ${data.trim()}');
      });

      // Wait for core to be ready
      bool coreReady = false;
      for (int i = 0; i < 10; i++) {
        try {
          final res = await http.get(
            Uri.parse('http://127.0.0.1:12021/api/status'),
          );
          if (res.statusCode == 200 || res.statusCode == 404) {
            coreReady = true;
            print(
              '[CORE] Successfully pinged torrent streaming backend at 127.0.0.1:12021!',
            );
            break;
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (!coreReady) {
        print(
          '[CORE] WARNING: Failed to ping libcore backend after 5 seconds!',
        );
      }
    } catch (e) {
      print('[CORE] Failed to start libcore.exe: $e');
    }
  }

  SettingsService.instance.init();
  AddonRegistry.instance.init();
  AuthService.instance.init();

  FtvMedia3PlayerController().setConfig(
    localeStrings: const {'loading': 'Loading stream...'},
  );

  runApp(const TelitaApp());
}

class TelitaApp extends StatefulWidget {
  const TelitaApp({super.key});

  @override
  State<TelitaApp> createState() => _TelitaAppState();
}

class _TelitaAppState extends State<TelitaApp> with WindowListener {
  bool _isGlobalFullscreen = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.addListener(this);
      HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
      HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    }
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
      _isGlobalFullscreen = !_isGlobalFullscreen;
      if (_isGlobalFullscreen) {
        windowManager.setFullScreen(true);
      } else {
        windowManager.setFullScreen(false);
      }
      return true;
    }
    return false;
  }

  void _saveWindowBounds() async {
    final prefs = await SharedPreferences.getInstance();
    final isMaximized = await windowManager.isMaximized();
    final isMinimized = await windowManager.isMinimized();

    if (!isMaximized && !isMinimized) {
      final bounds = await windowManager.getBounds();
      await prefs.setDouble('window_width', bounds.width);
      await prefs.setDouble('window_height', bounds.height);
      await prefs.setDouble('window_x', bounds.left);
      await prefs.setDouble('window_y', bounds.top);
    }
    await prefs.setBool('window_maximized', isMaximized);
  }

  @override
  void onWindowResized() {
    _saveWindowBounds();
  }

  @override
  void onWindowMoved() {
    _saveWindowBounds();
  }

  @override
  void onWindowMaximize() {
    _saveWindowBounds();
  }

  @override
  void onWindowUnmaximize() {
    _saveWindowBounds();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: SettingsService.instance,
      builder: (context, settings, child) {
        final isOled = settings.appTheme == 'black';
        final isCustom = settings.appTheme == 'custom';

        Color parseColor(String hexStr, Color fallback) {
          hexStr = hexStr.toUpperCase().replaceAll('#', '');
          if (hexStr.length == 6) hexStr = 'FF$hexStr';
          return Color(int.tryParse(hexStr, radix: 16) ?? fallback.value);
        }

        final primaryColor = isCustom
            ? parseColor(settings.customSecondaryColor, const Color(0xFF38BDF8))
            : (isOled ? const Color(0xFFE2E8F0) : const Color(0xFF38BDF8));

        final backgroundColor = isCustom
            ? parseColor(settings.customPrimaryColor, const Color(0xFF0F172A))
            : (isOled ? Colors.black : const Color(0xFF0F172A));

        return MaterialApp(
          title: 'Telita',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: backgroundColor,
            colorScheme: ColorScheme.dark(
              primary: primaryColor,
              secondary: primaryColor,
              surface: backgroundColor,
            ),
            fontFamily: 'Inter',
            useMaterial3: true,
            pageTransitionsTheme: PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              },
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class AppContainer extends StatefulWidget {
  const AppContainer({super.key});

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer> {
  Screen _currentScreen = Screen.home;
  bool _showAuthScreen = false;
  bool _showProfileSelect = false;
  String? _playbackPoster;

  MetaPreview? _selectedDetailItem;
  String? _selectedDetailType;
  String? _selectedInitialVideoId;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);

    // =========================================================
    // EXTENSIVE MEDIA_KIT DEBUGGING
    // =========================================================
    FtvMedia3PlayerController().playerStateStream.listen((state) {
      final ts = DateTime.now().toIso8601String();
      final stateVal = state.stateValue;
      print(
        ' [$ts][PLAYER] state=$stateVal | activityReady=${state.activityReady} | activityDestroyed=${state.activityDestroyed}',
      );

      // Print the current URL being played
      if (state.playlist.isNotEmpty) {
        print(' [$ts][PLAYER] url=${state.playlist.first.url}');
      }

      // Print volume state
      print(
        ' [$ts][PLAYER] volume=${state.volumeState?.volume} isMute=${state.volumeState?.isMute}',
      );

      if (state.activityDestroyed) {
        print('🛑 [$ts][PLAYER] Activity DESTROYED — stopping backend streams');
        _stopTorrents();
      }
    });
  }

  Future<void> _stopTorrents() async {
    try {
      await http.get(Uri.parse('http://127.0.0.1:12021/api/stop'));
    } catch (e) {
      print('Failed to stop torrents: $e');
    }
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final state = AuthService.instance.value;
    if (state.ready) {
      if (state.user == null && !state.isGuest) {
        setState(() {
          _showAuthScreen = true;
          _showProfileSelect = false;
        });
      } else if (state.user != null && state.profile == null) {
        setState(() {
          _showAuthScreen = false;
          _showProfileSelect = true;
        });
      } else {
        setState(() {
          _showAuthScreen = false;
          _showProfileSelect = false;
        });
      }
    }
  }

  void _playStream(
    BuildContext context,
    String url,
    String type,
    String id, {
    int? initialPosition,
    MetaPreview? item,
    String? name,
    String? poster,
    Map<String, String>? headers,
    List<MediaSegment>? segments,
    List<MediaItemSubtitle>? subtitles,
  }) async {
    final mediaItemName =
        name ?? item?.name ?? _selectedDetailItem?.name ?? 'Unknown Content';
    final mediaItemPoster =
        poster ?? item?.poster ?? _selectedDetailItem?.poster;

    List<MediaSegment>? finalSegments = segments;
    if (finalSegments == null && !SettingsService.instance.value.debugDisableSkipSegments) {
      finalSegments = await SkipSegmentClient.fetchSkipSegments(id);
    }

    double maxProgress = 0;
    bool shouldPlayNext = false;
    bool hasNextEp = false;
    MetaVideo? nextVideo;

    if (type == 'series' && item != null && item.videos != null) {
      final idx = item.videos!.indexWhere((v) => v.id == id);
      if (idx != -1 && idx < item.videos!.length - 1) {
        hasNextEp = true;
        nextVideo = item.videos![idx + 1];
      }
    }

    final Map<String, String>? effectiveHeaders =
        (headers != null && headers.isNotEmpty) ? headers : null;

    final originalUrl = url;
    print(' [PLAY] Requested stream: $originalUrl');

    // Only resolve 302 redirects via HEAD requests for non-HTTPS http:// links.
    // Presigned HTTPS links (Cloudflare R2, AWS S3, etc.) reject HEAD requests and
    // custom headers with 403 Forbidden (SigV4 signature mismatch) and MUST be passed as-is.
    if (url.startsWith('http://') &&
        !url.contains('X-Amz-') &&
        !url.contains('Signature=')) {
      try {
        final request = await HttpClient()
            .headUrl(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        request.followRedirects = false;

        if (effectiveHeaders != null) {
          effectiveHeaders.forEach((k, v) {
            try {
              request.headers.set(k, v);
            } catch (_) {}
          });
        }

        final response = await request.close();
        print(' [PLAY] HEAD $url → HTTP ${response.statusCode}');
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers.value('location');
          if (location != null) {
            url = location;
            print(' [PLAY] Resolved redirect → $url');
          } else {
            print(
              '⚠️ [PLAY] Got ${response.statusCode} but no Location header!',
            );
          }
        }
      } catch (e) {
        print('⚠️ [PLAY] HEAD request failed ($e), using original URL');
      }
    }

    print(' [PLAY] Final URL passed to player: $url');

    List<MediaItemSubtitle>? effectiveSubtitles = subtitles;
    if (effectiveSubtitles == null || effectiveSubtitles.isEmpty) {
      try {
        final addonSubs = await AddonRegistry.instance.getSubtitles(type, id);
        if (addonSubs.isNotEmpty) {
          effectiveSubtitles = addonSubs.map((sub) {
            final langCode = sub.lang.isNotEmpty ? sub.lang : 'en';
            final label = sub.addonName?.isNotEmpty == true ? sub.addonName! : '${langCode.toUpperCase()} (Addon)';
            return MediaItemSubtitle(
              url: sub.url,
              language: langCode,
              label: label,
            );
          }).toList();
        }
      } catch (_) {}
    }

    final cfg = SettingsService.instance.value;

    // Local files are fully offline — suppress Simkl, watch history, resume seek, next-episode
    final bool isLocalFile =
        originalUrl.startsWith('file://') ||
        originalUrl.startsWith('/') ||
        (originalUrl.length > 2 && originalUrl[1] == ':');

    String playerUrl = url;
    final mediaItems = [
      PlaylistMediaItem(
        id: id,
        url: playerUrl,
        originalUrl: originalUrl,
        title: mediaItemName,
        coverImg: mediaItemPoster,
        mediaItemType: MediaItemType.video,
        startPosition: isLocalFile ? null : initialPosition,
        headers: effectiveHeaders,
        subtitles: effectiveSubtitles,
        segments: finalSegments,
        saveWatchTime: (isLocalFile || cfg.debugDisableWatchHistory)
            ? null
            : ({
                required id,
                required duration,
                required position,
                required playIndex,
              }) async {
                if (duration > 0) {
                  double prog = (position / duration) * 100;
                  if (prog > maxProgress) maxProgress = prog;
                }

                if (position > 5 && duration > 0) {
                  WatchHistory.instance.save(
                    WatchEntry(
                      id: id,
                      type: type,
                      name: mediaItemName,
                      poster: mediaItemPoster,
                      streamUrl: originalUrl,
                      timestamp: position,
                      duration: duration,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                    ),
                  );
                }
              },
        onScrobble: (isLocalFile || cfg.debugDisableSimkl)
            ? null
            : ({required action, required position, required duration}) async {
                double progress = 0;
                if (duration > 0) {
                  progress = (position / duration) * 100;
                }
                await SimklClient.scrobbleEvent(
                  action: action,
                  type: type,
                  contentId: id,
                  progress: progress,
                );
              },
        hasNextEpisode: isLocalFile ? false : hasNextEp,
        nextEpisodeTitle: isLocalFile ? null : nextVideo?.title,
        nextEpisodeThumbnail: isLocalFile ? null : nextVideo?.thumbnail,
        nextEpisodeSeason: isLocalFile ? null : nextVideo?.season,
        nextEpisodeNumber: isLocalFile ? null : nextVideo?.episode,
        onNextEpisode: isLocalFile
            ? null
            : () {
                shouldPlayNext = true;
                Navigator.of(context).pop();
              },
      ),
    ];

    // ── STREAMING PLAYBACK (FtvMedia3) ──────────────────────────────────────

    SubtitleEdgeType edgeType = SubtitleEdgeType.none;
    if (cfg.subtitleStyle == 'shadow') edgeType = SubtitleEdgeType.dropShadow;
    if (cfg.subtitleStyle == 'outline') edgeType = SubtitleEdgeType.outline;

    FtvMedia3PlayerController().setConfig(
      localeStrings: const {'loading': 'Loading stream...'},
      subtitleStyle: SubtitleStyle(
        applyEmbeddedStyles: true,
        textSizeFraction: cfg.subtitleFontSize / 32.0,
        windowColor: cfg.subtitleBgOpacity > 0
            ? ExtendedColors.fromHex(
                '#${(cfg.subtitleBgOpacity * 2.55).round().toRadixString(16).padLeft(2, '0')}000000',
              )
            : ExtendedColors.transparent,
        edgeType: edgeType,
      ),
      playerSettings: PlayerSettings(
        preferredTextLanguages: cfg.subtitleEnabled
            ? [cfg.subtitleLanguage]
            : [],
        forcedAutoEnable: cfg.subtitleEnabled,
        hardwareDecoding: cfg.hardwareDecoding,
      ),
    );

    await FtvMedia3PlayerController().openPlayer(
      context: context,
      playlist: mediaItems,
      initialIndex: 0,
    );

    if (type == 'series' &&
        item != null &&
        (shouldPlayNext || maxProgress > 99.0)) {
      final videos = item.videos;
      if (videos != null) {
        final currentIdx = videos.indexWhere((v) => v.id == id);
        if (currentIdx != -1 && currentIdx < videos.length - 1) {
          final nextVideo = videos[currentIdx + 1];
          setState(() {
            _selectedInitialVideoId = nextVideo.id;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthState>(
      valueListenable: AuthService.instance,
      builder: (context, authState, _) {
        final stateReady = authState.ready;
        final needsAuth =
            stateReady && authState.user == null && !authState.isGuest;

        return WillPopScope(
          onWillPop: () async {
            if (_selectedDetailItem != null) {
              setState(() => _selectedDetailItem = null);
              return false;
            } else if (_showProfileSelect) {
              setState(() => _showProfileSelect = false);
              return false;
            } else if (_showAuthScreen) {
              setState(() => _showAuthScreen = false);
              return false;
            }
            return true;
          },
          child: Scaffold(
            body: Stack(
              children: [
                Builder(
                  builder: (context) {
                    final isPortrait =
                        MediaQuery.of(context).orientation ==
                        Orientation.portrait;
                    if (isPortrait) {
                      return Scaffold(
                        backgroundColor: Colors.transparent,
                        extendBody: true,
                        body: SafeArea(
                          bottom: false,
                          child: ExcludeFocus(
                            excluding:
                                _showAuthScreen ||
                                needsAuth ||
                                _showProfileSelect ||
                                (authState.user != null &&
                                    authState.profile == null),
                            child: _buildMainContent(),
                          ),
                        ),
                        bottomNavigationBar: _buildBottomNavBar(context),
                      );
                    }

                    return Row(
                      children: [
                        Sidebar(
                          currentScreen: _currentScreen,
                          onNavigate: (s) {
                            setState(() {
                              _selectedDetailItem = null;
                              _currentScreen = s;
                            });
                          },
                          onManageProfile: () {
                            setState(() {
                              if (authState.user != null) {
                                _showProfileSelect = true;
                              } else {
                                _showAuthScreen = true;
                              }
                            });
                          },
                          isGuest: authState.isGuest,
                          profileName:
                              authState.profile?.name ?? authState.user?.email,
                          avatarUrl: authState.profile?.avatarUrl,
                        ),
                        Expanded(
                          child: ExcludeFocus(
                            excluding:
                                _showAuthScreen ||
                                needsAuth ||
                                _showProfileSelect ||
                                (authState.user != null &&
                                    authState.profile == null),
                            child: _buildMainContent(),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                if (_showAuthScreen || needsAuth)
                  AuthScreen(
                    canClose: !needsAuth,
                    onClose: () => setState(() => _showAuthScreen = false),
                    onDone: () => setState(() => _showAuthScreen = false),
                  ),

                if (_showProfileSelect ||
                    (authState.user != null && authState.profile == null))
                  Positioned.fill(
                    child: ProfileSelectScreen(
                      onDone: () => setState(() => _showProfileSelect = false),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: SafeArea(
            bottom: true,
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Screen.home, Icons.explore_outlined, Icons.explore, 'Discover'),
                  _buildNavItem(Screen.addons, Icons.extension_outlined, Icons.extension, 'Addons'),
                  _buildNavItem(Screen.downloads, Icons.download_outlined, Icons.download, 'Downloads'),
                  _buildNavItem(Screen.settings, Icons.settings_outlined, Icons.settings, 'Settings'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(Screen screen, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentScreen == screen;
    final color = isSelected ? Theme.of(context).colorScheme.primary : Colors.white54;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDetailItem = null;
          _currentScreen = screen;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        ExcludeFocus(
          excluding: _selectedDetailItem != null,
          child: FadeIndexedStack(
            index: _currentScreen.index,
            children: [
              ExcludeFocus(
                excluding: _currentScreen != Screen.home,
                child: DiscoverScreen(
                  onManageProfile: () {
                    setState(() {
                      if (AuthService.instance.value.user != null) {
                        _showProfileSelect = true;
                      } else {
                        _showAuthScreen = true;
                      }
                    });
                  },
                  onSelect: (item, type, {initialVideoId}) {
                    setState(() {
                      _selectedDetailItem = item;
                      _selectedDetailType = type;
                      _selectedInitialVideoId = initialVideoId;
                    });
                  },
                  onResume: (entry) {
                    final baseId = entry.id.split(':')[0];
                    final metaItem = MetaPreview(
                      id: baseId,
                      type: entry.type,
                      name: entry.name,
                      poster: entry.poster,
                    );
                    setState(() {
                      _selectedDetailItem = metaItem;
                      _selectedDetailType = entry.type;
                      _selectedInitialVideoId = entry.id;
                    });
                    _playStream(
                      context,
                      entry.streamUrl,
                      entry.type,
                      entry.id,
                      initialPosition: entry.timestamp,
                      name: entry.name,
                      poster: entry.poster,
                      item: metaItem,
                    );
                  },
                ),
              ),
              ExcludeFocus(
                excluding: _currentScreen != Screen.addons,
                child: const AddonScreen(),
              ),
              ExcludeFocus(
                excluding: _currentScreen != Screen.downloads,
                child: DownloadsScreen(
                  onSelect: (item, type, {initialVideoId}) {
                    setState(() {
                      _selectedDetailItem = item;
                      _selectedDetailType = type;
                      _selectedInitialVideoId = initialVideoId;
                    });
                  },
                ),
              ),
              ExcludeFocus(
                excluding: _currentScreen != Screen.settings,
                child: const SettingsScreen(),
              ),
            ],
          ),
        ),
        if (_selectedDetailItem != null)
          Positioned.fill(
            child: FocusScope(
              autofocus: true,
              child: DetailScreen(
                key: ValueKey(
                  '${_selectedDetailItem!.id}_$_selectedInitialVideoId',
                ),
                item: _selectedDetailItem!,
                type: _selectedDetailType!,
                initialVideoId: _selectedInitialVideoId,
                isOffline: _currentScreen == Screen.downloads,
                onBack: () => setState(() {
                  _selectedDetailItem = null;
                  _selectedInitialVideoId = null;
                }),
                onPlay: (url, type, id, {headers, segments, meta, subtitles}) =>
                    _playStream(
                      context,
                      url,
                      type,
                      id,
                      item: meta ?? _selectedDetailItem,
                      headers: headers,
                      segments: segments,
                      subtitles: subtitles,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
    super.initState();
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    if (widget.index != oldWidget.index) {
      _controller.forward(from: 0.0);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ui/sidebar.dart';
import 'ui/auth_screen.dart';
import 'ui/profile_select_screen.dart';
import 'ui/discover_screen.dart';
import 'ui/addon_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/detail_screen.dart';
import 'core/auth.dart';
import 'core/addon_client.dart';
import 'core/watch_history.dart';
import 'core/settings.dart';
import 'ui/splash_screen.dart';
import 'dart:io';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';

import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    MediaKit.ensureInitialized();
  }

  if (Platform.isWindows || Platform.isLinux) {
    try {
      final executable = Platform.isWindows ? 'libcore.exe' : './libcore';
      final coreProcess = await Process.start(executable, []);
      print('[CORE] $executable started with PID: ${coreProcess.pid}');

      // Wait for core to be ready
      bool coreReady = false;
      for (int i = 0; i < 10; i++) {
        try {
          final res = await http.get(Uri.parse('http://127.0.0.1:8081/'));
          if (res.statusCode == 200 || res.statusCode == 404) {
            coreReady = true;
            print(
              '[CORE] Successfully pinged torrent streaming backend at 127.0.0.1:8081!',
            );
            break;
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (!coreReady) {
        print(
          '❌ [CORE] WARNING: Failed to ping libcore backend after 5 seconds!',
        );
      }
    } catch (e) {
      print('❌ [CORE] Failed to start libcore.exe: $e');
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

class TelitaApp extends StatelessWidget {
  const TelitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: SettingsService.instance,
      builder: (context, settings, child) {
        final isOled = settings.appTheme == 'black';

        return MaterialApp(
          title: 'Telita',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: isOled
                ? Colors.black
                : const Color(0xFF0F172A),
            colorScheme: ColorScheme.dark(
              primary: isOled
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFF38BDF8),
              secondary: isOled
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFF38BDF8),
              surface: isOled ? Colors.black : const Color(0xFF1E293B),
            ),
            fontFamily: 'Inter',
            useMaterial3: true,
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

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);

    FtvMedia3PlayerController().playerStateStream.listen((state) {
      if (state.activityDestroyed) {
        _stopTorrents();
      }
    });
  }

  Future<void> _stopTorrents() async {
    try {
      await http.get(Uri.parse('http://127.0.0.1:8081/api/stop'));
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
  }) {
    final mediaItemName =
        name ?? item?.name ?? _selectedDetailItem?.name ?? 'Unknown Content';
    final mediaItemPoster =
        poster ?? item?.poster ?? _selectedDetailItem?.poster;

    final mediaItems = [
      PlaylistMediaItem(
        id: id,
        url: url,
        title: mediaItemName,
        coverImg: mediaItemPoster,
        mediaItemType: MediaItemType.video,
        startPosition: initialPosition,
        saveWatchTime:
            ({
              required id,
              required duration,
              required position,
              required playIndex,
            }) async {
              if (position > 5 && duration > 0) {
                WatchHistory.instance.save(
                  WatchEntry(
                    id: id,
                    type: type,
                    name: mediaItemName,
                    poster: mediaItemPoster,
                    streamUrl: url,
                    timestamp: position,
                    duration: duration,
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                  ),
                );
              }
            },
      ),
    ];

    final cfg = SettingsService.instance.value;

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
      ),
    );

    FtvMedia3PlayerController().openPlayer(
      context: context,
      playlist: mediaItems,
      initialIndex: 0,
    );
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
                        body: SafeArea(
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
                        bottomNavigationBar: Theme(
                          data: Theme.of(context).copyWith(
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                          ),
                          child: BottomNavigationBar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            selectedItemColor: Colors.white,
                            unselectedItemColor: Colors.white54,
                            showSelectedLabels: false,
                            showUnselectedLabels: false,
                            type: BottomNavigationBarType.fixed,
                            currentIndex: _currentScreen.index,
                            onTap: (idx) {
                              setState(() {
                                _selectedDetailItem = null;
                                _currentScreen = Screen.values[idx];
                              });
                            },
                            items: const [
                              BottomNavigationBarItem(
                                icon: Icon(Icons.explore_outlined),
                                activeIcon: Icon(Icons.explore),
                                label: 'Discover',
                              ),
                              BottomNavigationBarItem(
                                icon: Icon(Icons.extension_outlined),
                                activeIcon: Icon(Icons.extension),
                                label: 'Addons',
                              ),
                              BottomNavigationBarItem(
                                icon: Icon(Icons.settings_outlined),
                                activeIcon: Icon(Icons.settings),
                                label: 'Settings',
                              ),
                            ],
                          ),
                        ),
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
                  onSelect: (item, type) {
                    setState(() {
                      _selectedDetailItem = item;
                      _selectedDetailType = type;
                    });
                  },
                  onResume: (entry) {
                    _playStream(
                      context,
                      entry.streamUrl,
                      entry.type,
                      entry.id,
                      initialPosition: entry.timestamp,
                      name: entry.name,
                      poster: entry.poster,
                    );
                  },
                ),
              ),
              ExcludeFocus(
                excluding: _currentScreen != Screen.addons,
                child: const AddonScreen(),
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
                item: _selectedDetailItem!,
                type: _selectedDetailType!,
                onBack: () => setState(() => _selectedDetailItem = null),
                onPlay: (url, type, id) => _playStream(
                  context,
                  url,
                  type,
                  id,
                  item: _selectedDetailItem,
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

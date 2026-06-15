import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/addon_client.dart';
import '../core/watch_history.dart';
import '../core/auth.dart';
import 'spinning_logo.dart';

class DiscoverScreen extends StatefulWidget {
  final Function(MetaPreview item, String type) onSelect;
  final Function(WatchEntry entry) onResume;
  final VoidCallback? onManageProfile;

  const DiscoverScreen({
    super.key,
    required this.onSelect,
    required this.onResume,
    this.onManageProfile,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class CatalogGroup {
  final String id;
  final String title;
  final List<MetaPreview> items;

  CatalogGroup({required this.id, required this.title, required this.items});
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _searchActive = false;
  final FocusNode _searchFocusNode = FocusNode();

  List<CatalogGroup> _catalogs = [];
  List<SearchResultGroup> _searchResults = [];
  bool _loadingCatalogs = true;
  bool _searchLoading = false;
  bool _searched = false;
  String _query = "";

  String? _expandedCatalogId;

  @override
  void initState() {
    super.initState();
    _loadAllCatalogs();
    WatchHistory.instance.init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCatalogs() async {
    setState(() {
      _loadingCatalogs = true;
      _catalogs = [];
    });

    await AddonRegistry.instance.init();
    final sources = AddonRegistry.instance.getCatalogSources();

    // Filter catalogs that do not require extra inputs
    final rootCatalogs = sources.where((src) {
      final hasRequiredExtra =
          src.catalog.extra?.any((e) => e['isRequired'] == true) ?? false;
      return !hasRequiredExtra;
    }).toList();

    List<CatalogGroup> loadedGroups = [];

    // Fetch sequentially to prevent network socket exhaustion and SSL Handshake failures on weak TV network stacks
    for (int i = 0; i < rootCatalogs.length; i++) {
      if (!mounted) break;

      final src = rootCatalogs[i];
      try {
        final results = await AddonRegistry.instance.fetchCatalog(
          src.addon,
          src.catalog,
        );
        if (results.isNotEmpty) {
          final typeLabel = src.catalog.type == 'movie'
              ? 'Movies'
              : src.catalog.type == 'series'
              ? 'Series'
              : (src.catalog.type.substring(0, 1).toUpperCase() +
                    src.catalog.type.substring(1));

          final group = CatalogGroup(
            id: "${src.addon.manifest.id}-${src.catalog.id}-${src.catalog.type}",
            title: "${src.catalog.name ?? src.catalog.id} - $typeLabel",
            items: results,
          );

          if (mounted) {
            loadedGroups.add(group);
            setState(() {
              _catalogs = List.from(loadedGroups);
              _loadingCatalogs =
                  false; // Stop main loading indicator once first catalog is ready
            });
          }
        }
      } catch (e) {
        print("Error fetching catalog: $e");
      }

      // Yield to the event loop so the UI doesn't stutter on TVs
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _onQueryChanged(String text) {
    setState(() {
      _query = text;
    });
  }

  void _executeSearch(String text) async {
    if (text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searched = false;
        _searchLoading = false;
      });
      return;
    }

    setState(() {
      _searchLoading = true;
      _searched = true;
    });

    await AddonRegistry.instance.init();
    final results = await AddonRegistry.instance.search(text.trim());
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    }
  }

  String _guessType(MetaPreview item) {
    return item.type == "series" ? "series" : "movie";
  }

  HeroInfo? _heroInfo;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _query.trim().isEmpty && _expandedCatalogId == null,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_expandedCatalogId != null) {
          setState(() => _expandedCatalogId = null);
        } else if (_query.trim().isNotEmpty) {
          _searchController.clear();
          _onQueryChanged("");
          _executeSearch("");
        }
      },
      child: Scaffold(
        body: Focus(
          child: Stack(
            children: [
              // HERO BACKDROP
              if (_heroInfo != null &&
                  _heroInfo!.poster != null &&
                  _expandedCatalogId == null &&
                  _query.trim().isEmpty)
                Positioned(
                  top: 0,
                  right: 0,
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      key: ValueKey(_heroInfo!.poster),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: _heroInfo!.poster!,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              memCacheWidth: 600,
                            ),
                          ),

                          // Strong Horizontal fade to left
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.1),
                                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                                    Theme.of(context).scaffoldBackgroundColor,
                                    Theme.of(context).scaffoldBackgroundColor,
                                  ],
                                  stops: const [0.0, 0.4, 0.7, 0.9, 1.0], // Reaches solid bg before container edge
                                ),
                              ),
                            ),
                          ),
                          // Vertical fade to bottom
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                                    Theme.of(context).scaffoldBackgroundColor,
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // FOREGROUND CONTENT
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar Header
                    if (_expandedCatalogId == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        child: Center(
                          child: Focus(
                            onFocusChange: (focused) {
                              setState(() {
                                if (!focused && !_searchFocusNode.hasFocus) {
                                  _searchActive = false;
                                }
                              });
                            },
                            onKeyEvent: (node, event) {
                              // Only intercept Enter to open the search field when it's not already focused.
                              // If the TextField already has focus, let Enter pass through so onSubmitted fires.
                              if (!_searchFocusNode.hasFocus &&
                                  event is KeyDownEvent &&
                                  (event.logicalKey.keyLabel == 'Enter' ||
                                      event.logicalKey.keyLabel == 'Select')) {
                                setState(() => _searchActive = true);
                                _searchFocusNode.requestFocus();
                                SystemChannels.textInput.invokeMethod(
                                  'TextInput.show',
                                );
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(
                              builder: (context) {
                                final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
                                final authState = AuthService.instance.value;
                                final bool isFocused =
                                    Focus.of(context).hasFocus ||
                                    _searchFocusNode.hasFocus;
                                final content = Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 400,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: isFocused
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.white.withOpacity(0.05),
                                      width: isFocused ? 2 : 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.search,
                                        color: Colors.white30,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Focus(
                                          onKeyEvent: (node, event) {
                                            if (MediaQuery.of(
                                                  context,
                                                ).viewInsets.bottom >
                                                0) {
                                              if (event is KeyDownEvent ||
                                                  event is KeyRepeatEvent) {
                                                if (event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .arrowLeft ||
                                                    event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .arrowRight ||
                                                    event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .arrowUp ||
                                                    event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .arrowDown) {
                                                  return KeyEventResult
                                                      .skipRemainingHandlers;
                                                }
                                              }
                                            }
                                            return KeyEventResult.ignored;
                                          },
                                          child: TextField(
                                            controller: _searchController,
                                            focusNode: _searchFocusNode,
                                            readOnly: (Platform.isWindows || Platform.isMacOS || Platform.isLinux || isPortrait) ? false : !_searchActive,
                                            textInputAction:
                                                TextInputAction.search,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            onTap: () {
                                              setState(() => _searchActive = true);
                                              _searchFocusNode.requestFocus();
                                            },
                                            onSubmitted: (value) {
                                              setState(
                                                () => _searchActive = false,
                                              );
                                              _executeSearch(value);
                                              FocusScope.of(
                                                context,
                                              ).requestFocus(
                                                Focus.of(context),
                                              ); // Return focus to container
                                            },
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Search movies, series across all addons...',
                                              hintStyle: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.3),
                                              ),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                              isDense: true,
                                            ),
                                            onChanged: _onQueryChanged,
                                          ),
                                        ),
                                      ),
                                      if (_query.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            color: Colors.white30,
                                            size: 18,
                                          ),
                                          focusNode: FocusNode(
                                            skipTraversal: true,
                                          ), // Don't let D-pad focus the clear button easily
                                          onPressed: () {
                                            _searchController.clear();
                                            _onQueryChanged("");
                                            _executeSearch("");
                                          },
                                        ),
                                    ],
                                  ),
                                );

                                Widget searchResult = content;
                                if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux || isPortrait)) {
                                  searchResult = GestureDetector(
                                    onTap: () {
                                      setState(() => _searchActive = true);
                                      _searchFocusNode.requestFocus();
                                      SystemChannels.textInput.invokeMethod(
                                        'TextInput.show',
                                      );
                                    },
                                    child: content,
                                  );
                                }

                                if (isPortrait) {
                                  return Row(
                                    children: [
                                      Image.asset('assets/logo.png', width: 28, height: 28, color: Colors.white70, colorBlendMode: BlendMode.srcIn),
                                      const SizedBox(width: 16),
                                      Expanded(child: Center(child: searchResult)),
                                      const SizedBox(width: 16),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: widget.onManageProfile,
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.white24,
                                          backgroundImage: authState.profile?.avatarUrl != null 
                                              ? (authState.profile!.avatarUrl!.startsWith('http') 
                                                  ? NetworkImage(authState.profile!.avatarUrl!) as ImageProvider
                                                  : AssetImage('assets/pfps/${authState.profile!.avatarUrl!.split('/').last}'))
                                              : null,
                                          child: authState.profile?.avatarUrl == null
                                              ? (authState.isGuest
                                                  ? const Icon(Icons.person_outline, color: Colors.white, size: 20)
                                                  : Text(
                                                      ((authState.profile?.name ?? authState.user?.email ?? 'ME').substring(0, 2)).toUpperCase(),
                                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ))
                                              : null,
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return searchResult;
                              },
                            ),
                          ),
                        ),
                      ),

                    // Hero Info Overlay
                    if (_query.isEmpty &&
                        _heroInfo != null &&
                        _expandedCatalogId == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            if (_heroInfo!.categoryTitle != null)
                              Text(
                                _heroInfo!.categoryTitle!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            Text(
                              _heroInfo!.title,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (_heroInfo!.description != null &&
                                _heroInfo!.description!.isNotEmpty)
                              SizedBox(
                                width: 500,
                                child: Text(
                                  _heroInfo!.description!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),

                    // Main Body Scroll
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                            ],
                            stops: [0.0, 0.02, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: _query.trim().isNotEmpty
                            ? _buildSearchResults()
                            : _buildCatalogsSection(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchLoading) {
      return const Center(child: BrandLoadingIndicator(color: Colors.white70));
    }

    if (_searched && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              'No results for "$_query"',
              style: const TextStyle(color: Colors.white30, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _searchResults.length,
      itemBuilder: (context, idx) {
        final group = _searchResults[idx];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.catalogName,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 255, // increased to accommodate 1.05 scale
              child: ListView.builder(
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: group.results.length,
                itemBuilder: (context, itemIdx) {
                  final item = group.results[itemIdx];
                  return PosterCard(
                    item: item,
                    onSelect: widget.onSelect,
                    type: _guessType(item),
                    onFocus: (focused) {
                      if (focused) {
                        setState(() {
                          _heroInfo = HeroInfo(
                            item.name,
                            item.background ?? item.poster,
                            item.description,
                            _guessType(item),
                            group.catalogName,
                          );
                        });
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildCatalogsSection() {
    return ValueListenableBuilder<List<WatchEntry>>(
      valueListenable: WatchHistory.instance,
      builder: (context, watchEntries, _) {
        final hasWatchHistory =
            watchEntries.isNotEmpty && _expandedCatalogId == null;

        int itemCount = 0;
        if (hasWatchHistory) itemCount++;
        if (_loadingCatalogs) {
          itemCount++;
        } else {
          itemCount += _catalogs.length;
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            int currentIdx = index;

            if (hasWatchHistory) {
              if (currentIdx == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Continue Watching',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => WatchHistory.instance.clear(),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.white30),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 255,
                      child: ListView.builder(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: watchEntries.length,
                        itemBuilder: (context, idx) {
                          final entry = watchEntries[idx];
                          return ContinueWatchingCard(
                            entry: entry,
                            onResume: widget.onResume,
                            onSelect: widget.onSelect,
                            autofocus: idx == 0,
                            onFocus: (focused) {
                              if (focused) {
                                setState(() {
                                  _heroInfo = HeroInfo(
                                    entry.name ?? 'Unknown',
                                    entry.poster,
                                    null,
                                    entry.type,
                                    'Continue Watching',
                                  );
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              }
              currentIdx--;
            }

            if (_loadingCatalogs) {
              if (currentIdx == 0) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: const BrandLoadingIndicator(color: Colors.white70),
                  ),
                );
              }
              return const SizedBox();
            }

            final group = _catalogs[currentIdx];
            final isExpanded = _expandedCatalogId == group.id;
            if (_expandedCatalogId != null && !isExpanded)
              return const SizedBox();

            return Builder(
              builder: (categoryContext) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (isExpanded)
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _expandedCatalogId = null),
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                label: Text(
                                  'Back',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white30,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              group.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    isExpanded
                        ? GridView.builder(
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.all(8),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 160,
                                  mainAxisExtent: 240,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: group.items.length,
                            itemBuilder: (context, idx) {
                              return PosterCard(
                                item: group.items[idx],
                                showTitle: true,
                                onSelect: widget.onSelect,
                                type: _guessType(group.items[idx]),
                                autofocus:
                                    idx == 0 &&
                                    watchEntries.isEmpty &&
                                    currentIdx == 0,
                                onFocus: (focused) {
                                  if (focused) {
                                    Scrollable.ensureVisible(
                                      categoryContext,
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      alignment: 0.35,
                                    );
                                    setState(() {
                                      _heroInfo = HeroInfo(
                                        group.items[idx].name,
                                        group.items[idx].background ??
                                            group.items[idx].poster,
                                        group.items[idx].description,
                                        _guessType(group.items[idx]),
                                        group.title,
                                      );
                                    });
                                  }
                                },
                              );
                            },
                          )
                        : SizedBox(
                            height: 255,
                            child: ListView.builder(
                              clipBehavior: Clip.none,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              scrollDirection: Axis.horizontal,
                              itemCount: group.items.length.clamp(0, 10),
                              itemBuilder: (context, idx) {
                                return PosterCard(
                                  item: group.items[idx],
                                  onSelect: widget.onSelect,
                                  type: _guessType(group.items[idx]),
                                  autofocus:
                                      idx == 0 &&
                                      watchEntries.isEmpty &&
                                      currentIdx == 0,
                                  onFocus: (focused) {
                                    if (focused) {
                                      Scrollable.ensureVisible(
                                        categoryContext,
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        alignment: 0.35,
                                      );
                                      setState(() {
                                        _heroInfo = HeroInfo(
                                          group.items[idx].name,
                                          group.items[idx].background ??
                                              group.items[idx].poster,
                                          group.items[idx].description,
                                          _guessType(group.items[idx]),
                                          group.title,
                                        );
                                      });
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class PosterCard extends StatefulWidget {
  final MetaPreview item;
  final bool showTitle;
  final Function(MetaPreview, String) onSelect;
  final String type;
  final bool autofocus;
  final Function(bool)? onFocus;

  const PosterCard({
    super.key,
    required this.item,
    this.showTitle = false,
    required this.onSelect,
    required this.type,
    this.autofocus = false,
    this.onFocus,
  });

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  void _handleFocus(bool val) {
    setState(() => _isFocused = val);
    if (widget.onFocus != null) widget.onFocus!(val);
  }

  void _handleHover(bool val) {
    setState(() => _isHovered = val);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isFocused || _isHovered ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: _isFocused
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      if (widget.item.poster != null)
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: widget.item.poster!,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                          ),
                        )
                      else
                        const Center(
                          child: Icon(
                            Icons.movie,
                            color: Colors.white30,
                            size: 40,
                          ),
                        ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            autofocus: widget.autofocus,
                            onFocusChange: _handleFocus,
                            onHover: _handleHover,
                            onTap: () =>
                                widget.onSelect(widget.item, widget.type),
                            child: Center(
                              child: Opacity(
                                opacity: 0.0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.showTitle) ...[
              const SizedBox(height: 6),
              Text(
                widget.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ContinueWatchingCard extends StatefulWidget {
  final WatchEntry entry;
  final Function(WatchEntry) onResume;
  final Function(MetaPreview, String) onSelect;
  final bool autofocus;
  final Function(bool)? onFocus;

  const ContinueWatchingCard({
    super.key,
    required this.entry,
    required this.onResume,
    required this.onSelect,
    this.autofocus = false,
    this.onFocus,
  });

  @override
  State<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  void _handleFocus(bool val) {
    setState(() => _isFocused = val);
    if (widget.onFocus != null) widget.onFocus!(val);
  }

  void _handleHover(bool val) {
    setState(() => _isHovered = val);
  }

  @override
  Widget build(BuildContext context) {
    final progress = WatchHistory.instance.getProgress(widget.entry);

    return AnimatedScale(
      scale: _isFocused || _isHovered ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: _isFocused
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              Positioned.fill(
                bottom: 4,
                child: widget.entry.poster != null
                    ? CachedNetworkImage(
                        imageUrl: widget.entry.poster!,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                      )
                    : Container(color: Colors.white10),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.black.withOpacity(0.2),
                  child: InkWell(
                    autofocus: widget.autofocus,
                    onFocusChange: _handleFocus,
                    onHover: _handleHover,
                    onTap: () => widget.onResume(widget.entry),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 12,
                child: GestureDetector(
                  onTap: () {
                    final previewItem = MetaPreview(
                      id: widget.entry.id,
                      type: widget.entry.type,
                      name: widget.entry.name,
                      poster: widget.entry.poster,
                    );
                    widget.onSelect(previewItem, widget.entry.type);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: GestureDetector(
                  onTap: () {
                    WatchHistory.instance.remove(widget.entry.id);
                    setState(
                      () {},
                    ); // trigger rebuild if necessary, or let parent handle
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 4,
                child: Container(
                  color: Colors.white24,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeroInfo {
  final String title;
  final String? poster;
  final String? description;
  final String type;
  final String? categoryTitle;

  HeroInfo(
    this.title,
    this.poster,
    this.description,
    this.type, [
    this.categoryTitle,
  ]);
}

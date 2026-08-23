import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/settings.dart';
import '../../core/catalog_config.dart';
import '../../core/addon_client.dart';
import '../../core/simkl_client.dart';
import 'settings_widgets.dart';

class CatalogSettingsScreen extends StatefulWidget {
  const CatalogSettingsScreen({super.key});

  @override
  State<CatalogSettingsScreen> createState() => _CatalogSettingsScreenState();
}

class _CatalogItemInfo {
  final String id;
  final String title;

  _CatalogItemInfo({required this.id, required this.title});
}

class _CatalogSettingsScreenState extends State<CatalogSettingsScreen> {
  late CatalogConfig _config;
  bool _isLoading = true;
  List<_CatalogItemInfo> _availableCatalogs = [];
  String? _reorderingId;

  @override
  void initState() {
    super.initState();
    _config = CatalogConfig.fromString(SettingsService.instance.value.catalogConfigJson);
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    List<_CatalogItemInfo> items = [];

    // 1. Continue Watching
    items.add(_CatalogItemInfo(id: 'continue_watching', title: 'Continue Watching'));

    // 2. Simkl
    if (SettingsService.instance.value.simklEnabled && SettingsService.instance.value.simklAccessToken.isNotEmpty) {
      items.add(_CatalogItemInfo(id: 'simkl-watching', title: 'Simkl Watchlist - Watching'));
      items.add(_CatalogItemInfo(id: 'simkl-plantowatch', title: 'Simkl Watchlist - Plan to Watch'));
      items.add(_CatalogItemInfo(id: 'simkl-completed', title: 'Simkl Watchlist - Completed'));
    }

    // 3. Addons
    await AddonRegistry.instance.init();
    final sources = AddonRegistry.instance.getCatalogSources();
    final rootCatalogs = sources.where((src) {
      final hasRequiredExtra = src.catalog.extra?.any((e) => e['isRequired'] == true) ?? false;
      return !hasRequiredExtra;
    }).toList();

    for (final src in rootCatalogs) {
      final typeLabel = src.catalog.type == 'movie'
          ? 'Movies'
          : src.catalog.type == 'series'
              ? 'Series'
              : (src.catalog.type.substring(0, 1).toUpperCase() + src.catalog.type.substring(1));
      
      final id = "${src.addon.manifest.id}-${src.catalog.id}-${src.catalog.type}";
      final title = "${src.catalog.name ?? src.catalog.id} - $typeLabel";
      
      items.add(_CatalogItemInfo(id: id, title: title));
    }

    // Sort items according to config.order
    List<_CatalogItemInfo> sortedItems = [];
    for (String id in _config.order) {
      final matchIdx = items.indexWhere((c) => c.id == id);
      if (matchIdx != -1) {
        sortedItems.add(items[matchIdx]);
      }
    }
    
    // Add any missing items (newly discovered) to the end
    for (final item in items) {
      if (!_config.order.contains(item.id)) {
        sortedItems.add(item);
      }
    }

    if (mounted) {
      setState(() {
        _availableCatalogs = sortedItems;
        _isLoading = false;
      });
    }
  }

  void _saveConfig() {
    // Update the order based on _availableCatalogs
    _config.order = _availableCatalogs.map((e) => e.id).toList();
    SettingsService.instance.set('catalogConfigJson', _config.toStringConfig());
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _availableCatalogs.removeAt(oldIndex);
      _availableCatalogs.insert(newIndex, item);
    });
    _saveConfig();
  }

  void _swapItems(int oldIndex, int newIndex) {
    setState(() {
      final item = _availableCatalogs.removeAt(oldIndex);
      _availableCatalogs.insert(newIndex, item);
    });
    _saveConfig();
  }

  void _toggleHidden(String id, bool isHidden) {
    setState(() {
      if (isHidden) {
        _config.hidden.add(id);
      } else {
        _config.hidden.remove(id);
      }
    });
    _saveConfig();
  }

  Future<void> _changeLimit(BuildContext context, String id, int currentLimit) async {
    int tempLimit = currentLimit;
    final newLimit = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text('Set Item Limit', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$tempLimit items', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 16),
                TVSlider(
                  value: tempLimit.toDouble(),
                  min: 5,
                  max: 100,
                  divisions: 19, // Steps of 5 (100-5 = 95 / 19 = 5)
                  onChanged: (val) {
                    setDialogState(() {
                      tempLimit = val.toInt();
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(tempLimit),
                child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          );
        },
      ),
    );

    if (newLimit != null) {
      setState(() {
        _config.limits[id] = newLimit;
      });
      _saveConfig();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.secondary;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Discover Page'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    buildDefaultDragHandles: false,
                    itemCount: _availableCatalogs.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                final catalog = _availableCatalogs[index];
                final isHidden = _config.hidden.contains(catalog.id);
                final limit = _config.limits[catalog.id] ?? (catalog.id == 'continue_watching' ? 20 : 50);
                final isReordering = _reorderingId == catalog.id;

                return Focus(
                  key: ValueKey(catalog.id),
                  onKeyEvent: (node, event) {
                    if (isReordering && (event is KeyDownEvent || event is KeyRepeatEvent)) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        if (index > 0) _swapItems(index, index - 1);
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        if (index < _availableCatalogs.length - 1) _swapItems(index, index + 1);
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
                        setState(() => _reorderingId = null);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Card(
                    elevation: isReordering ? 8 : 1,
                    color: isReordering ? accentColor.withOpacity(0.2) : Theme.of(context).colorScheme.surface,
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      onLongPress: () {
                        setState(() => _reorderingId = catalog.id);
                      },
                      onTap: () {
                        if (isReordering) {
                          setState(() => _reorderingId = null);
                        } else {
                          _toggleHidden(catalog.id, !isHidden);
                        }
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Icon(isReordering ? Icons.unfold_more : Icons.drag_handle, color: isReordering ? accentColor : Colors.white54),
                      ),
                      title: Text(
                        catalog.title,
                        style: TextStyle(
                          color: isHidden ? Colors.white38 : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: isHidden
                          ? const Text('Hidden', style: TextStyle(color: Colors.white38))
                          : Text(isReordering ? 'Use UP/DOWN to move, OK to drop' : 'Limit: $limit items', style: TextStyle(color: isReordering ? accentColor : Colors.white54)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isHidden && !isReordering)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.white54),
                              onPressed: () => _changeLimit(context, catalog.id, limit),
                            ),
                          if (!isReordering)
                            IgnorePointer(
                              child: Switch(
                                value: !isHidden,
                                activeColor: accentColor,
                                onChanged: (v) {},
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
        ],
      ),
    );
  }
}

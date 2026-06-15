import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/addon_client.dart';
import 'spinning_logo.dart';

class AddonScreen extends StatefulWidget {
  const AddonScreen({super.key});

  @override
  State<AddonScreen> createState() => _AddonScreenState();
}

class _AddonScreenState extends State<AddonScreen> {
  List<InstalledAddon> _addons = [];
  final String _query = "";
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  bool _loading = true;
  bool _installing = false;
  String _installError = "";

  @override
  void initState() {
    super.initState();
    _loadAddons();
  }

  Future<void> _loadAddons() async {
    setState(() => _loading = true);
    await AddonRegistry.instance.init();
    if (mounted) {
      setState(() {
        _addons = AddonRegistry.instance.getAll();
        _loading = false;
      });
    }
  }

  List<InstalledAddon> _filteredAddons() {
    if (_query.trim().isEmpty) return _addons;
    final q = _query.toLowerCase();
    return _addons.where((a) {
      return a.manifest.name.toLowerCase().contains(q) ||
          a.manifest.description.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _handleToggle(InstalledAddon addon) async {
    if (addon.installed) {
      AddonRegistry.instance.uninstall(addon.manifest.id);
    } else {
      try {
        final manifestUrl = "${addon.transportUrl}/manifest.json";
        await AddonRegistry.instance.install(manifestUrl);
      } catch (e) {
        print("Failed to enable addon: $e");
      }
    }
    setState(() {
      _addons = AddonRegistry.instance.getAll();
    });
  }

  Future<void> _handleRemove(InstalledAddon addon) async {
    AddonRegistry.instance.remove(addon.manifest.id);
    setState(() {
      _addons = AddonRegistry.instance.getAll();
    });
  }

  Future<void> _handleConfigure(InstalledAddon addon) async {
    final urlStr = "${addon.transportUrl}/configure";
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open configuration URL: $urlStr')),
        );
      }
    }
  }

  void _showAddAddonDialog() {
    _urlController.clear();
    _installError = "";
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text(
                'Add Addon',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paste the manifest.json URL of any Stremio-compatible addon.\nExample: https://v3-cinemeta.strem.io/manifest.json',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    onKeyEvent: (node, event) {
                      if (MediaQuery.of(context).viewInsets.bottom > 0) {
                        if (event is KeyDownEvent || event is KeyRepeatEvent) {
                          if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowLeft ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.arrowRight ||
                              event.logicalKey == LogicalKeyboardKey.arrowUp ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.arrowDown) {
                            return KeyEventResult.skipRemainingHandlers;
                          }
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://example.com/manifest.json',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  if (_installError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _installError,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _installing ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _installing
                      ? null
                      : () async {
                          final url = _urlController.text.trim();
                          if (url.isEmpty) return;
                          setModalState(() {
                            _installing = true;
                            _installError = "";
                          });
                          try {
                            await AddonRegistry.instance.install(url);
                            if (mounted) {
                              setState(() {
                                _addons = AddonRegistry.instance.getAll();
                              });
                            }
                            Navigator.pop(context);
                          } catch (e) {
                            setModalState(() {
                              _installError = e
                                  .toString()
                                  .replaceAll('Exception:', '')
                                  .trim();
                            });
                          } finally {
                            setModalState(() {
                              _installing = false;
                            });
                          }
                        },
                  child: Text(_installing ? 'Installing...' : 'Install'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAddons();
    final activeCount = _addons.where((a) => a.installed).length;
    final inactiveCount = _addons.where((a) => !a.installed).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Addon Manager',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$activeCount addons active  ·  $inactiveCount inactive',
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Add addon button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _showAddAddonDialog,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Add Addon',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Body Content
              Expanded(
                child: _loading
                    ? const Center(child: BrandLoadingIndicator(size: 60))
                    : list.isEmpty
                    ? const Center(
                        child: Text(
                          'No addons installed matching your search.',
                          style: TextStyle(color: Colors.white30, fontSize: 16),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth <= 0)
                            return const SizedBox();
                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 450,
                                  mainAxisExtent: 200,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                ),
                            itemCount: list.length,
                            itemBuilder: (context, idx) {
                              final addon = list[idx];
                              // Only allow drag if not filtering
                              if (_query.trim().isNotEmpty) {
                                return _buildAddonCard(addon);
                              }

                              return LongPressDraggable<String>(
                                data: addon.manifest.id,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Opacity(
                                    opacity: 0.8,
                                    child: SizedBox(
                                      width: 400,
                                      height: 200,
                                      child: _buildAddonCard(addon),
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildAddonCard(addon),
                                ),
                                child: DragTarget<String>(
                                  onAcceptWithDetails: (sourceId) {
                                    if (sourceId != addon.manifest.id) {
                                      final sourceIdx = _addons.indexWhere(
                                        (a) => a.manifest.id == sourceId,
                                      );
                                      final targetIdx = _addons.indexWhere(
                                        (a) =>
                                            a.manifest.id == addon.manifest.id,
                                      );
                                      if (sourceIdx >= 0 && targetIdx >= 0) {
                                        AddonRegistry.instance.reorder(
                                          sourceIdx,
                                          targetIdx,
                                        );
                                        setState(() {
                                          _addons = AddonRegistry.instance
                                              .getAll();
                                        });
                                      }
                                    }
                                  },
                                  builder:
                                      (context, candidateData, rejectedData) {
                                        return _buildAddonCard(addon);
                                      },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddonCard(InstalledAddon addon) {
    final tags = addon.manifest.resources
        .map((r) => r is String ? r : r['name'] ?? '')
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: addon.manifest.logo != null
                      ? CachedNetworkImage(
                          imageUrl: addon.manifest.logo!,
                          fit: BoxFit.contain,
                          memCacheWidth: 150,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.extension,
                            color: Colors.white30,
                            size: 28,
                          ),
                        )
                      : const Icon(
                          Icons.extension,
                          color: Colors.white30,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            addon.manifest.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'v${addon.manifest.version}',
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Active badge
                    if (addon.installed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Active',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Description
          Expanded(
            child: Text(
              addon.manifest.description,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Tags
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: tags.map((t) {
              if (t.isEmpty) return const SizedBox();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  t.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (addon.manifest.behaviorHints != null &&
                  addon.manifest.behaviorHints!['configurable'] == true) ...[
                TextButton.icon(
                  onPressed: () => _handleConfigure(addon),
                  icon: const Icon(Icons.settings, size: 14),
                  label: const Text(
                    'Configure',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
                const SizedBox(width: 8),
              ],
              TextButton(
                onPressed: () => _handleToggle(addon),
                style: TextButton.styleFrom(
                  foregroundColor: addon.installed
                      ? Colors.white54
                      : Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  addon.installed ? 'Disable' : 'Enable',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!addon.installed) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _handleRemove(addon),
                  style: TextButton.styleFrom(foregroundColor: Colors.white30),
                  child: const Text('Remove', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

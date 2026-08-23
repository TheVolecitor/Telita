import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/settings.dart';
import '../core/addon_client.dart';
import 'web_safe_image.dart';

class DownloadsScreen extends StatefulWidget {
  final FocusNode? sidebarFocusNode;
  final Function(MetaPreview item, String type, {String? initialVideoId}) onSelect;

  const DownloadsScreen({super.key, this.sidebarFocusNode, required this.onSelect});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<MetaPreview> _downloadedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scanDownloads();
  }

  Future<void> _scanDownloads() async {
    final path = SettingsService.instance.value.downloadPath;
    if (path.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final dir = Directory(path);
    if (!await dir.exists()) {
      setState(() => _isLoading = false);
      return;
    }

    List<MetaPreview> items = [];
    int totalBytes = 0;

    int _calculateSize(Directory dir) {
      int size = 0;
      try {
        if (dir.existsSync()) {
          for (var entity in dir.listSync(recursive: true)) {
            if (entity is File) {
              size += entity.lengthSync();
            }
          }
        }
      } catch (_) {}
      return size;
    }

    totalBytes = _calculateSize(dir);

    final entities = dir.listSync();
    for (var entity in entities) {
      if (entity is Directory) {
        final metaFile = File('${entity.path}${Platform.pathSeparator}meta.json');
        if (await metaFile.exists()) {
          try {
            final jsonStr = await metaFile.readAsString();
            final meta = jsonDecode(jsonStr);
            // Replace external URLs with local files if they exist
            final posterFile = File('${entity.path}${Platform.pathSeparator}poster.jpg');
            if (await posterFile.exists()) {
              meta['poster'] = posterFile.uri.toString();
            }
            final backdropFile = File('${entity.path}${Platform.pathSeparator}backdrop.jpg');
            if (await backdropFile.exists()) {
              meta['background'] = backdropFile.uri.toString();
            }
            items.add(MetaPreview.fromJson(meta));
          } catch (e) {
            print('Error parsing meta.json in ${entity.path}: $e');
          }
        }
      }
    }

    setState(() {
      _downloadedItems = items;
      _totalOccupiedSpace = totalBytes;
      _isLoading = false;
    });
  }

  int _totalOccupiedSpace = 0;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _showQueue() {
    showDialog(
      context: context,
      builder: (context) => DownloadQueueDialog(
        onCancelledOrRemoved: _scanDownloads,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Downloads',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (_totalOccupiedSpace > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${_formatBytes(_totalOccupiedSpace)} occupied',
                            style: const TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _scanDownloads();
                        },
                        tooltip: 'Refresh Downloads',
                      ),
                      const SizedBox(width: 16),
                      _QueueButton(onTap: _showQueue),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _downloadedItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.download_for_offline_outlined,
                                  size: 72, color: Colors.white12),
                              const SizedBox(height: 16),
                              const Text(
                                'No downloads yet.',
                                style: TextStyle(color: Colors.white38, fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Right-click or long-press a stream to download it.',
                                style: TextStyle(color: Colors.white24, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ValueListenableBuilder<AppSettings>(
                          valueListenable: SettingsService.instance,
                          builder: (context, settings, _) {
                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 160 * settings.discoverScale,
                                childAspectRatio: 140 / 255,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _downloadedItems.length,
                              itemBuilder: (context, index) {
                                final item = _downloadedItems[index];
                                return _DownloadPosterCard(
                                  item: item,
                                  autofocus: index == 0,
                                  onSelect: (it, type) => widget.onSelect(it, type),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

}

// ── Queue Button with live badge ─────────────────────────────────────────────

class _QueueButton extends StatefulWidget {
  final VoidCallback onTap;
  const _QueueButton({required this.onTap});

  @override
  State<_QueueButton> createState() => _QueueButtonState();
}

class _QueueButtonState extends State<_QueueButton> {
  int _activeCount = 0;
  Timer? _timer;
  bool _isVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isVisible = TickerMode.of(context);
  }

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (kIsWeb) return;
    if (!_isVisible) return;
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:12021/api/download/status'));
      if (res.statusCode == 200 && mounted) {
        final List<dynamic> list = jsonDecode(res.body) as List<dynamic>? ?? [];
        final active = list.where((s) => s['status'] == 'downloading').length;
        if (active != _activeCount) setState(() => _activeCount = active);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: widget.onTap,
          icon: const Icon(Icons.download_rounded, size: 20),
          label: const Text('Queue'),
        ),
        if (_activeCount > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$_activeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Download Poster Card (matches Discover) ───────────────────────────────────

class _DownloadPosterCard extends StatefulWidget {
  final MetaPreview item;
  final bool autofocus;
  final void Function(MetaPreview, String) onSelect;

  const _DownloadPosterCard({
    required this.item,
    required this.onSelect,
    this.autofocus = false,
  });

  @override
  State<_DownloadPosterCard> createState() => _DownloadPosterCardState();
}

class _DownloadPosterCardState extends State<_DownloadPosterCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = _isFocused || _isHovered;
    final poster = widget.item.poster;
    final name = widget.item.name ?? '';

    return AnimatedScale(
      scale: active ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
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
                    if (poster != null)
                      Positioned.fill(
                        child: poster.startsWith('file://')
                            ? Image.file(
                                File.fromUri(Uri.parse(poster)),
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stackTrace) => const SizedBox(),
                              )
                            : WebSafeImage(
                                imageUrl: poster,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                memCacheWidth: 400,
                                errorWidget: (context, url, error) => const SizedBox(),
                              ),
                      )
                    else
                      const Center(
                        child: Icon(Icons.movie, color: Colors.white30, size: 40),
                      ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          autofocus: widget.autofocus,
                          onFocusChange: (v) => setState(() => _isFocused = v),
                          onHover: (v) => setState(() => _isHovered = v),
                          onTap: () => widget.onSelect(widget.item, widget.item.type ?? 'movie'),
                          child: const Center(
                            child: Opacity(
                              opacity: 0.0,
                              child: Icon(Icons.play_arrow, color: Colors.white, size: 24),
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
          if (name.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              name,
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
    );
  }
}

class DownloadQueueDialog extends StatefulWidget {
  final VoidCallback? onCancelledOrRemoved;
  const DownloadQueueDialog({super.key, this.onCancelledOrRemoved});

  @override
  State<DownloadQueueDialog> createState() => _DownloadQueueDialogState();
}

class _DownloadQueueDialogState extends State<DownloadQueueDialog> {
  List<dynamic> _statuses = [];
  Timer? _timer;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetchStatuses();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) => _fetchStatuses());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatuses({bool force = false}) async {
    if (kIsWeb) return;
    if (_fetching && !force) return;
    _fetching = true;
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:12021/api/download/status'));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _statuses = jsonDecode(res.body) as List<dynamic>? ?? [];
        });
      }
    } catch (_) {
    } finally {
      _fetching = false;
    }
  }

  Future<void> _doAction(String endpoint, String id) async {
    try {
      await http.post(
        Uri.parse('http://127.0.0.1:12021/api/download/$endpoint'),
        body: jsonEncode({'id': id}),
      );
      await _fetchStatuses(force: true);
      widget.onCancelledOrRemoved?.call();
    } catch (_) {}
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'downloading': return Theme.of(context).colorScheme.primary;
      case 'paused': return Theme.of(context).colorScheme.secondary;
      case 'completed': return const Color(0xFF6C63FF);
      case 'error': return Colors.redAccent;
      case 'cancelled': return Colors.white38;
      default: return Colors.white38;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'downloading': return Icons.download_rounded;
      case 'paused': return Icons.pause_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'error': return Icons.error_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          color: const Color(0xFF121218),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.download_rounded, color: Colors.white70, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Download Queue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_statuses.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_statuses.length} item${_statuses.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            // List
            Flexible(
              child: _statuses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: Colors.white12),
                          SizedBox(height: 12),
                          Text('Queue is empty', style: TextStyle(color: Colors.white38, fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _statuses.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0x0FFFFFFF), height: 1),
                      itemBuilder: (context, index) {
                        final s = _statuses[index];
                        final id = s['id'] as String;
                        final title = s['title'] ?? 'Unknown';
                        final total = (s['totalBytes'] as num).toInt();
                        final down = (s['downloadedBytes'] as num).toInt();
                        final speed = (s['speedBytes'] as num).toDouble();
                        final status = s['status'] as String;
                        final errorMsg = s['errorMsg'] as String? ?? '';

                        final pct = total > 0 ? (down / total).clamp(0.0, 1.0) : 0.0;
                        final isActive = status == 'downloading';
                        final isPaused = status == 'paused';
                        final isError = status == 'error';
                        final isCancelled = status == 'cancelled';
                        final isDone = status == 'completed';
                        final canResume = isPaused || isCancelled || isError;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _statusColor(context, status).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _statusIcon(status),
                                        color: _statusColor(context, status),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _statusColor(context, status).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(_statusIcon(status), size: 14, color: _statusColor(context, status)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    status.toUpperCase(),
                                                    style: TextStyle(
                                                      color: _statusColor(context, status),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isActive) ...[const SizedBox(width: 8), Text(_formatSpeed(speed), style: const TextStyle(color: Colors.white54, fontSize: 11))],
                                            if (isError && errorMsg.isNotEmpty) ...[const SizedBox(width: 8), Expanded(child: Text(errorMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.redAccent, fontSize: 11)))],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isActive)
                                        _ActionButton(icon: Icons.pause_rounded, color: Theme.of(context).colorScheme.secondary, tooltip: 'Pause', onTap: () => _doAction('pause', id)),
                                      if (canResume)
                                        _ActionButton(icon: Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.primary, tooltip: 'Resume', onTap: () => _doAction('resume', id)),
                                      if (isActive || isPaused)
                                        _ActionButton(icon: Icons.cancel_rounded, color: Theme.of(context).colorScheme.error, tooltip: 'Cancel', onTap: () => _doAction('cancel', id)),
                                      if (!isActive && !isPaused)
                                        _ActionButton(icon: Icons.clear_rounded, color: Colors.white38, tooltip: 'Remove', onTap: () => _doAction('remove', id)),
                                    ],
                                  ),
                                ],
                              ),
                              if (total > 0 || isActive) ...[  
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 4,
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          color: _statusColor(context, status).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: pct.clamp(0.0, 1.0),
                                        child: Container(
                                          height: double.infinity,
                                          decoration: BoxDecoration(
                                            color: _statusColor(context, status),
                                            borderRadius: BorderRadius.circular(2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _statusColor(context, status).withOpacity(0.4),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      total > 0 ? '${_formatBytes(down)} / ${_formatBytes(total)}' : _formatBytes(down),
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                    Text(
                                      '${(pct * 100).toStringAsFixed(2)}%',
                                      style: TextStyle(color: _statusColor(context, status).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small circular action button ────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: _hovered ? widget.color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.color, size: 18),
          ),
        ),
      ),
    );
  }
}



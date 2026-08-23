import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'web_safe_image.dart';
import 'package:flutter/foundation.dart';
import '../core/addon_client.dart';
import '../core/skip_segment_client.dart';
import '../core/settings.dart';
import '../core/mdblist_client.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import 'badges.dart';
import 'spinning_logo.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class DetailScreen extends StatefulWidget {
  final MetaPreview item;
  final String type; // "movie" | "series"
  final String? initialVideoId;
  final bool isOffline;
  final VoidCallback onBack;
  final Function(
    String url,
    String type,
    String id, {
    Map<String, String>? headers,
    List<MediaSegment>? segments,
    MetaPreview? meta,
    List<MediaItemSubtitle>? subtitles,
  })
  onPlay;

  const DetailScreen({
    super.key,
    required this.item,
    required this.type,
    this.initialVideoId,
    this.isOffline = false,
    required this.onBack,
    required this.onPlay,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  MetaPreview? _meta;
  MdbListRatings? _mdbListRatings;
  List<StreamModel> _streams = [];
  List<Subtitle> _subtitles = [];
  bool _subtitlesLoading = false;
  List<InstalledAddon> _streamAddons = [];
  Set<String> _loadingAddonNames = {};
  Map<String, int> _addonStreamCounts = {};
  bool _loading = true;
  bool _streamsLoading = false;
  String? _resolvingHash;

  int _selectedSeason = 1;
  String _selectedVideoId = "";
  bool _viewingStreams = false;
  String _selectedAddon = "all";

  int _getSelectedEpisode() {
    int episodeNum = 1;
    if (_meta != null && _meta!.videos != null) {
      for (var v in _meta!.videos!) {
        if (v.id == _selectedVideoId) {
          if (v.episode != null) return v.episode!;
        }
      }
    }
    final parts = _selectedVideoId.split(':');
    if (parts.length >= 3) {
      episodeNum = int.tryParse(parts[2]) ?? 1;
    }
    return episodeNum;
  }

  @override
  void initState() {
    super.initState();
    _viewingStreams = widget.type == "movie";
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _loading = true;
    });

    if (widget.isOffline) {
      await _loadMetadataOffline();
    } else {
      await AddonRegistry.instance.init();
      final m = await AddonRegistry.instance.getMeta(widget.type, widget.item.id);

      _loadMdbListRatings();

      if (mounted) {
        setState(() {
          _meta = m ?? widget.item;
          _loading = false;
        });
      }
    }


    if (widget.type == "movie") {
      _fetchStreams(widget.item.id);
      _fetchSubtitles(widget.item.id);
    } else {
      final videos = (_meta ?? widget.item).videos;
      if (videos != null && videos.isNotEmpty) {
        MetaVideo? targetVid;
        if (widget.initialVideoId != null) {
          try {
            targetVid = videos.firstWhere((v) => v.id == widget.initialVideoId);
          } catch (_) {
            final parts = widget.initialVideoId!.split(':');
            if (parts.length >= 3) {
              final targetSeason = int.tryParse(parts[1]);
              final targetEp = int.tryParse(parts[2]);
              try {
                targetVid = videos.firstWhere(
                  (v) => v.season == targetSeason && v.episode == targetEp,
                );
              } catch (_) {}
            }
          }
        }
          if (targetVid == null) {
            try {
              targetVid = videos.firstWhere((v) => v.season != null && v.season! > 0);
            } catch (_) {
              targetVid = videos[0];
            }
          }

        setState(() {
          if (targetVid!.season != null) _selectedSeason = targetVid.season!;
          _selectedVideoId = targetVid.id;
          if (widget.initialVideoId != null) {
            _viewingStreams = true;
          }
        });
        _fetchStreams(targetVid.id);
        _fetchSubtitles(targetVid.id);
      }
    }
  }

  Future<void> _loadMetadataOffline() async {
    final baseDir = SettingsService.instance.value.downloadPath;
    final title = widget.item.name;
    final year = widget.item.releaseInfo ?? '';
    final folderName = year.isNotEmpty ? "$title ($year)" : title;
    final sanitizedFolder = folderName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    final seriesDir = Directory("$baseDir${Platform.pathSeparator}$sanitizedFolder");

    List<MetaVideo> videos = [];

    if (widget.type == 'series' && seriesDir.existsSync()) {
      final seasons = seriesDir.listSync().whereType<Directory>();
      for (final season in seasons) {
        if (season.path.contains('Season ')) {
          final episodes = season.listSync().whereType<Directory>();
          for (final epDir in episodes) {
            if (epDir.path.contains('Episode ')) {
              final metaFile = File("${epDir.path}${Platform.pathSeparator}meta.json");
              if (metaFile.existsSync()) {
                try {
                  final jsonStr = await metaFile.readAsString();
                  final metaJson = jsonDecode(jsonStr);
                  
                  videos.add(MetaVideo(
                    id: metaJson['id'] ?? '',
                    title: metaJson['name'] ?? metaJson['title'] ?? 'Unknown Episode',
                    season: metaJson['season'],
                    episode: metaJson['episode'],
                    thumbnail: metaJson['thumbnail'],
                  ));
                } catch (_) {}
              }
            }
          }
        }
      }
      
      videos.sort((a, b) {
        if (a.season != b.season) return (a.season ?? 0).compareTo(b.season ?? 0);
        return (a.episode ?? 0).compareTo(b.episode ?? 0);
      });
    }

    if (mounted) {
      setState(() {
        _meta = MetaPreview(
          id: widget.item.id,
          type: widget.item.type,
          name: widget.item.name,
          poster: widget.item.poster,
          background: widget.item.background,
          description: widget.item.description,
          releaseInfo: widget.item.releaseInfo,
          videos: videos,
        );
        _loading = false;
      });
    }
  }

  Future<void> _fetchSubtitles(String videoId) async {
    if (widget.isOffline) {
      if (mounted) setState(() { _subtitlesLoading = false; _subtitles = []; });
      return;
    }
    setState(() {
      _subtitlesLoading = true;
      _subtitles = [];
    });
    try {
      final subs = await AddonRegistry.instance.getSubtitles(
        widget.type,
        videoId,
      );
      if (mounted) {
        setState(() {
          _subtitles = subs;
          _subtitlesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _subtitlesLoading = false);
    }
  }

  Future<void> _fetchStreams(String videoId) async {
    if (widget.isOffline) {
      _loadOfflineStreams(videoId);
      return;
    }

    final addons = AddonRegistry.instance.getStreamAddons(widget.type, videoId);
    setState(() {
      _streamAddons = addons;
      _loadingAddonNames = addons.map((a) => a.manifest.name).toSet();
      _addonStreamCounts = {};
      _streams = [];
      _streamsLoading = addons.isNotEmpty;
    });

    if (addons.isEmpty) return;

    for (final addon in addons) {
      AddonRegistry.instance
          .getStreamsFromAddon(addon, widget.type, videoId)
          .then((newStreams) {
            if (!mounted) return;
            setState(() {
              _loadingAddonNames.remove(addon.manifest.name);
              _addonStreamCounts[addon.manifest.name] = newStreams.length;
              if (newStreams.isNotEmpty) {
                _streams.addAll(newStreams);
              }
              if (_loadingAddonNames.isEmpty) {
                _streamsLoading = false;
              }
            });
          })
          .catchError((e) {
            if (!mounted) return;
            setState(() {
              _loadingAddonNames.remove(addon.manifest.name);
              _addonStreamCounts[addon.manifest.name] = 0;
              if (_loadingAddonNames.isEmpty) {
                _streamsLoading = false;
              }
            });
          });
    }
  }

  void _loadOfflineStreams(String videoId) {
    setState(() {
      _streamsLoading = true;
      _streams = [];
    });

    final baseDir = SettingsService.instance.value.downloadPath;
    final title = widget.item.name ?? 'Unknown';
    final year = widget.item.releaseInfo ?? '';
    final folderName = year.isNotEmpty ? "$title ($year)" : title;
    final sanitizedFolder = folderName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    
    String targetDir;
    String fileName;
    if (widget.type == 'series') {
      final season = _selectedSeason.toString().padLeft(2, '0');
      final episode = _getSelectedEpisode().toString().padLeft(2, '0');
      targetDir = "$baseDir${Platform.pathSeparator}$sanitizedFolder${Platform.pathSeparator}Season $season${Platform.pathSeparator}Episode $episode";
      fileName = "$sanitizedFolder S${season}E${episode}.mp4";
    } else {
      targetDir = "$baseDir${Platform.pathSeparator}$sanitizedFolder";
      fileName = "$sanitizedFolder.mp4";
    }

    if (Directory(targetDir).existsSync()) {
      final dir = Directory(targetDir);
      final files = dir.listSync();
      
      String? streamAddon = "Downloads";
      String? streamName = "Downloads";
      String? streamTitle;
      String? streamDescription;

      final metaFile = File("$targetDir${Platform.pathSeparator}meta.json");
      if (metaFile.existsSync()) {
        try {
          final m = jsonDecode(metaFile.readAsStringSync());
          if (m['stream_addon'] != null) streamAddon = m['stream_addon'];
          if (m['stream_name'] != null) streamName = m['stream_name'];
          if (m['stream_title'] != null) streamTitle = m['stream_title'];
          if (m['stream_description'] != null) streamDescription = m['stream_description'];
        } catch (_) {}
      }

      for (final f in files) {
        if (f is File) {
          final p = f.path.toLowerCase();
          if (p.endsWith('.mp4') || p.endsWith('.mkv') || p.endsWith('.avi')) {
            _streams.add(StreamModel(
              addonName: streamAddon,
              name: streamName,
              title: streamTitle ?? f.uri.pathSegments.last,
              description: streamDescription,
              url: f.uri.toString(),
            ));
          }
        }
      }
    }

    setState(() {
      _streamsLoading = false;
    });
  }

  static bool _hasValidRating(String? rating) {
    if (rating == null || rating.trim().isEmpty) return false;
    final r = rating.trim();
    if (r == '0' || r == '0.0' || r == '0.00' || r == 'null') return false;
    final val = double.tryParse(r);
    return val != null && val > 0;
  }

  static Map<String, dynamic> _decodeJsonMap(String body) =>
      jsonDecode(body) as Map<String, dynamic>;

  Future<String?> _resolveStreamUrl(String infoHash) async {
    try {
      final res = await http.get(
        Uri.parse("http://127.0.0.1:12021/api/play?infoHash=$infoHash"),
      );
      if (res.statusCode == 200) {
        final data = await compute(_decodeJsonMap, res.body);
        return data['streamUrl'];
      }
    } catch (e) {
      print("Error resolving stream: $e");
    }
    return null;
  }

  void _showTopToast(String message) {
    final bool isError = message.toLowerCase().contains("failed") || message.toLowerCase().contains("error");
    final color = isError ? Colors.redAccent : Theme.of(context).colorScheme.primary;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 120, // push it down a bit
          right: 20,
          left: 20,
        ),
        duration: const Duration(seconds: 3),
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleDownloadRequest(StreamModel stream) async {
    final sKey = stream.infoHash ?? stream.url ?? stream.externalUrl ?? stream.nzbUrl ?? stream.title ?? stream.hashCode.toString();
    setState(() => _resolvingHash = sKey);

    final headers = stream.behaviorHints?.proxyHeaders?.request;

    String? finalUrl;
    if (stream.url != null) {
      if (headers != null && headers.isNotEmpty) {
        final encodedUrl = Uri.encodeComponent(stream.url!);
        final encodedHeaders = Uri.encodeComponent(jsonEncode(headers));
        finalUrl = "http://127.0.0.1:12021/proxy/?d=$encodedUrl&proxyheaders=$encodedHeaders";
      } else {
        finalUrl = stream.url!;
      }
    } else if (stream.infoHash != null) {
      finalUrl = await _resolveStreamUrl(stream.infoHash!);
    } else if (stream.nzbUrl != null && stream.servers != null && stream.servers!.isNotEmpty) {
      final encodedUrl = Uri.encodeComponent(stream.nzbUrl!);
      final encodedServer = Uri.encodeComponent(stream.servers!.first);
      finalUrl = "http://127.0.0.1:12021/api/play/nzb?nzbUrl=$encodedUrl&server=$encodedServer";
    }

    setState(() => _resolvingHash = null);

    if (finalUrl == null) {
      _showTopToast('Failed to resolve stream for downloading.');
      return;
    }

    // Build nested path
    final baseDir = SettingsService.instance.value.downloadPath;
    if (baseDir.isEmpty) {
      _showTopToast('Please configure your Download Location in Settings first.');
      return;
    }

    final title = widget.item.name ?? 'Unknown';
    final year = widget.item.releaseInfo ?? '';
    final folderName = year.isNotEmpty ? "$title ($year)" : title;
    final sanitizedFolder = folderName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');

    String targetDir;

    if (widget.type == "series") {
      final season = _selectedSeason.toString().padLeft(2, '0');
      final episode = _getSelectedEpisode().toString().padLeft(2, '0');
      targetDir = "$baseDir${Platform.pathSeparator}$sanitizedFolder${Platform.pathSeparator}Season $season${Platform.pathSeparator}Episode $episode";
    } else {
      targetDir = "$baseDir${Platform.pathSeparator}$sanitizedFolder";
    }

    int? tentativeSize;
    String? preferredFileName;

    if (stream.url != null) {
      try {
        var res = await http.head(Uri.parse(stream.url!), headers: headers);
        if (res.statusCode >= 400 && res.statusCode != 404) {
          // Fallback to GET for servers that block HEAD
          res = await http.get(Uri.parse(stream.url!), headers: {...?headers, 'Range': 'bytes=0-0'});
        }
        if (res.statusCode >= 200 && res.statusCode < 400) {
          final contentLength = res.headers['content-length'];
          if (contentLength != null) {
            tentativeSize = int.tryParse(contentLength);
          }
          final contentDisposition = res.headers['content-disposition'];
          if (contentDisposition != null) {
            // Check for filename*
            final matchStar = RegExp(r"filename\*\s*=\s*(?:utf-8|iso-8859-1)'[^']*'([^;]+)", caseSensitive: false).firstMatch(contentDisposition);
            if (matchStar != null) {
              preferredFileName = Uri.decodeComponent(matchStar.group(1)!);
            } else {
              // Check for filename="..."
              final match = RegExp(r'filename\s*=\s*"([^"]+)"', caseSensitive: false).firstMatch(contentDisposition);
              if (match != null) {
                preferredFileName = match.group(1);
              } else {
                // Check for filename=...
                final match2 = RegExp(r'filename\s*=\s*([^;]+)', caseSensitive: false).firstMatch(contentDisposition);
                if (match2 != null) {
                  preferredFileName = match2.group(1)!.trim();
                }
              }
            }
          }
        }
        if (preferredFileName == null) {
          final path = Uri.parse(stream.url!).pathSegments.last;
          if (path.isNotEmpty && (path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mkv') || path.toLowerCase().endsWith('.avi'))) {
            preferredFileName = Uri.decodeComponent(path);
          }
        }
      } catch (e) {
        print("HEAD request failed: $e");
      }
    }

    if (preferredFileName == null && stream.behaviorHints?.filename != null) {
      preferredFileName = stream.behaviorHints!.filename;
    }

    if (preferredFileName != null) {
      preferredFileName = preferredFileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    }

    String fileName;
    if (widget.type == "series") {
      final season = _selectedSeason.toString().padLeft(2, '0');
      final episode = _getSelectedEpisode().toString().padLeft(2, '0');
      fileName = preferredFileName ?? "$sanitizedFolder S${season}E${episode}.mp4";
    } else {
      fileName = preferredFileName ?? "$sanitizedFolder.mp4";
    }

    String sizeText = "";
    if (tentativeSize != null) {
      final mb = tentativeSize / (1024 * 1024);
      if (mb > 1024) {
        sizeText = "\n\nTentative Size: ${(mb / 1024).toStringAsFixed(2)} GB";
      } else {
        sizeText = "\n\nTentative Size: ${mb.toStringAsFixed(2)} MB";
      }
    }

    if (!mounted) return;

    // Confirmation Dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Download Stream?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will download the stream to your library:\n$targetDir$sizeText',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              String? rootTargetDir;
              Map<String, dynamic>? rootMeta;
              Map<String, dynamic>? finalMeta;

              if (widget.type == "series") {
                rootTargetDir = "$baseDir${Platform.pathSeparator}$sanitizedFolder";
                rootMeta = {
                  'id': widget.item.id,
                  'name': widget.item.name,
                  'type': widget.type,
                  'poster': widget.item.poster,
                  'background': widget.item.background,
                  'releaseInfo': widget.item.releaseInfo,
                  'description': widget.item.description,
                };

                MetaVideo? currentVid;
                if (_meta?.videos != null) {
                  try {
                    currentVid = _meta!.videos!.firstWhere((v) => v.id == _selectedVideoId);
                  } catch (_) {}
                }

                final seasonStr = _selectedSeason.toString();
                final episodeStr = _getSelectedEpisode().toString();

                finalMeta = {
                  'id': _selectedVideoId,
                  'name': currentVid?.title ?? 'Episode $episodeStr',
                  'type': 'episode',
                  'season': int.tryParse(seasonStr) ?? 1,
                  'episode': int.tryParse(episodeStr) ?? 1,
                  'thumbnail': currentVid?.thumbnail ?? widget.item.poster,
                };
              } else {
                finalMeta = {
                  'id': widget.item.id,
                  'name': widget.item.name,
                  'type': widget.type,
                  'poster': widget.item.poster,
                  'background': widget.item.background,
                  'releaseInfo': widget.item.releaseInfo,
                  'description': widget.item.description,
                  'stream_addon': stream.addonName,
                  'stream_name': stream.name,
                  'stream_title': stream.title,
                  'stream_description': stream.description,
                };
              }

              if (finalMeta != null && widget.type == 'series') {
                finalMeta['stream_addon'] = stream.addonName;
                finalMeta['stream_name'] = stream.name;
                finalMeta['stream_title'] = stream.title;
                finalMeta['stream_description'] = stream.description;
              }

              final payload = {
                'id': sKey,
                'url': finalUrl,
                'targetDir': targetDir,
                'fileName': fileName,
                'meta': finalMeta,
                'posterUrl': widget.item.poster ?? '',
                'backdropUrl': widget.item.background ?? '',
                'rootTargetDir': rootTargetDir ?? '',
                'rootMeta': rootMeta,
              };

              try {
                final res = await http.post(
                  Uri.parse('http://127.0.0.1:12021/api/download/start'),
                  body: jsonEncode(payload),
                );
                if (res.statusCode == 200) {
                  _showTopToast('Download started.');
                } else {
                  _showTopToast('Failed to start download: ${res.body}');
                }
              } catch (e) {
                _showTopToast('Error starting download: $e');
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _handleStream(StreamModel stream) async {
    final subtitleQueryId = widget.type == "movie"
        ? widget.item.id
        : _selectedVideoId;
    final headers = stream.behaviorHints?.proxyHeaders?.request;

    final streamKey =
        stream.infoHash ??
        stream.url ??
        stream.externalUrl ??
        stream.nzbUrl ??
        stream.title ??
        stream.hashCode.toString();

    // Show a loading indicator in the play button while resolving or launching player
    setState(() {
      _resolvingHash = streamKey;
    });

    List<MediaSegment>? segments;
    if (!SettingsService.instance.value.debugDisableSkipSegments) {
      if (widget.type == "movie") {
        segments = await SkipSegmentClient.fetchSkipSegments(widget.item.id);
      } else {
        segments = await SkipSegmentClient.fetchSkipSegments(_selectedVideoId);
      }
    }

    final mediaSubtitles = _subtitles.map((sub) {
      final langCode = sub.lang.isNotEmpty ? sub.lang : 'en';
      final addon = (sub.addonName != null && sub.addonName!.isNotEmpty)
          ? sub.addonName!
          : 'Addon';
      return MediaItemSubtitle(url: sub.url, language: langCode, label: addon);
    }).toList();

    if (stream.url != null) {
      String playUrl = stream.url!;
      Map<String, String>? playerHeaders = headers;

      if (headers != null && headers.isNotEmpty) {
        final encodedUrl = Uri.encodeComponent(playUrl);
        final encodedHeaders = Uri.encodeComponent(jsonEncode(headers));
        playUrl =
            "http://127.0.0.1:12021/proxy/?d=$encodedUrl&proxyheaders=$encodedHeaders";
        playerHeaders = null; // Do not pass them to native player
      }

      widget.onPlay(
        playUrl,
        widget.type,
        subtitleQueryId,
        headers: playerHeaders,
        segments: segments,
        meta: _meta,
        subtitles: mediaSubtitles,
      );

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _resolvingHash = null);
      });
    } else if (stream.externalUrl != null) {
      if (mounted) setState(() => _resolvingHash = null);
      final uri = Uri.parse(stream.externalUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (stream.nzbUrl != null &&
        stream.servers != null &&
        stream.servers!.isNotEmpty) {
      final encodedUrl = Uri.encodeComponent(stream.nzbUrl!);
      final encodedServer = Uri.encodeComponent(stream.servers!.first);
      final playUrl =
          "http://127.0.0.1:12021/api/play/nzb?nzbUrl=$encodedUrl&server=$encodedServer";
      widget.onPlay(
        playUrl,
        widget.type,
        subtitleQueryId,
        segments: segments,
        meta: _meta,
        subtitles: mediaSubtitles,
      );
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _resolvingHash = null);
      });
    } else if (stream.infoHash != null) {
      final url = await _resolveStreamUrl(stream.infoHash!);
      if (mounted) {
        setState(() {
          _resolvingHash = null;
        });
      }
      if (url != null) {
        widget.onPlay(
          url,
          widget.type,
          subtitleQueryId,
          segments: segments,
          meta: _meta,
          subtitles: mediaSubtitles,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to resolve stream link. Make sure Core is running.',
            ),
          ),
        );
      }
    } else {
      if (mounted) setState(() => _resolvingHash = null);
    }
  }

  List<int> _availableSeasons() {
    final m = _meta;
    if (m?.videos == null) return [];
    final seasons = <int>{};
    for (final v in m!.videos!) {
      if (v.season != null) seasons.add(v.season!);
    }
    final list = seasons.toList();
    list.sort((a, b) {
      if (a == 0 && b != 0) return 1;
      if (b == 0 && a != 0) return -1;
      return a.compareTo(b);
    });
    return list;
  }

  List<MetaVideo> _availableEpisodes() {
    final m = _meta;
    if (m?.videos == null) return [];
    final eps = m!.videos!.where((v) => v.season == _selectedSeason).toList();
    eps.sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
    return eps;
  }

  List<String> _uniqueAddons() {
    final addons = _streams
        .map((s) => s.addonName ?? "Unknown")
        .toSet()
        .toList();
    return addons;
  }

  List<StreamModel> _filteredStreams() {
    if (_selectedAddon == "all") return _streams;
    return _streams.where((s) => s.addonName == _selectedAddon).toList();
  }

  @override
  Widget build(BuildContext context) {
    final backdropUrl =
        _meta?.background ?? _meta?.poster ?? widget.item.poster;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Backdrop image with overlay
          if (backdropUrl != null)
            Positioned.fill(
              child: backdropUrl.startsWith('file://')
                  ? Image.file(
                      File.fromUri(Uri.parse(backdropUrl)),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    )
                  : WebSafeImage(
                      imageUrl: backdropUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      memCacheWidth: 1200,
                      errorWidget: (context, url, error) => const SizedBox(),
                    ),
            ),
            Positioned.fill(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(SettingsService.instance.value.backdropOpacity),
              ),
            ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Main Layout
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    label: const Text(
                      'Back',
                      style: TextStyle(color: Colors.white70),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                // Content columns
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final isPortrait =
                          MediaQuery.of(context).orientation ==
                          Orientation.portrait;
                      final metadataColumn = Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isPortrait ? 16.0 : 32.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 375),
                            childAnimationBuilder: (widget) => SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(child: widget),
                            ),
                            children: [
                            if (_loading) ...[
                              const SizedBox(height: 20),
                              _buildSkeleton(width: 250, height: 35),
                              const SizedBox(height: 15),
                              _buildSkeleton(
                                width: double.infinity,
                                height: 80,
                              ),
                            ] else ...[
                              if (_meta?.logo != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20.0),
                                  child: _meta!.logo!.startsWith('file://')
                                      ? Image.file(
                                          File.fromUri(Uri.parse(_meta!.logo!)),
                                          height: 100,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.centerLeft,
                                          errorBuilder: (context, error, stackTrace) => Text(
                                            _meta?.name ?? widget.item.name,
                                            style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : WebSafeImage(
                                          imageUrl: _meta!.logo!,
                                          height: 100,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                          memCacheWidth: 600,
                                          alignment: Alignment.centerLeft,
                                          errorWidget: (context, url, error) => Text(
                                            _meta?.name ?? widget.item.name,
                                            style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                )
                              else
                                Text(
                                  _meta?.name ?? widget.item.name,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                              const SizedBox(height: 12),

                              // Badges / Meta row
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (_meta?.releaseInfo != null)
                                    _buildMetaText(_meta!.releaseInfo!),
                                  if (_meta?.runtime != null)
                                    _buildMetaText(_meta!.runtime!),
                                  if (_hasValidRating(_meta?.imdbRating))
                                    _buildMetaText('⭐ ${_meta!.imdbRating}'),
                                ],
                              ),

                              // MDBList Ratings
                              _buildMdbListBadges(),

                              // Genres
                              if (_meta?.genres != null &&
                                  _meta!.genres!.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                const Text(
                                  'GENRES',
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _meta!.genres!
                                      .map((g) => _buildPill(g))
                                      .toList(),
                                ),
                              ],

                              // Cast
                              if (_meta?.cast != null &&
                                  _meta!.cast!.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                const Text(
                                  'CAST',
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _meta!.cast!
                                      .map((c) => _buildPill(c))
                                      .toList(),
                                ),
                              ],

                              const SizedBox(height: 24),
                              Text(
                                _meta?.description ??
                                    "No description available.",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            ]),
                        ),
                      );

                      final contentPanel = Container(
                        margin: EdgeInsets.only(
                          right: isPortrait ? 16.0 : 32.0,
                          left: isPortrait ? 16.0 : 0,
                          bottom: 20.0,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: widget.type == "series" && !_viewingStreams
                            ? _buildEpisodesPanel(isPortrait)
                            : _buildStreamsPanel(isPortrait),
                      );

                      if (isPortrait) {
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              metadataColumn,
                              const SizedBox(height: 32),
                              contentPanel,
                            ],
                          ),
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(child: metadataColumn),
                          ),
                          Expanded(flex: 6, child: contentPanel),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaText(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  void _loadMdbListRatings() async {
    final cfg = SettingsService.instance.value;
    if (cfg.mdbListEnabled && cfg.mdbListApiKey.isNotEmpty) {
      final ratings = await MdbListClient.fetchRatings(
        widget.item.id,
        cfg.mdbListApiKey,
      );
      if (mounted) {
        setState(() {
          _mdbListRatings = ratings;
        });
      }
    }
  }

  Widget _buildMdbListBadges() {
    final cfg = SettingsService.instance.value;
    if (!cfg.mdbListEnabled ||
        _mdbListRatings == null ||
        cfg.mdbListApiKey.isEmpty)
      return const SizedBox.shrink();

    final widgets = <Widget>[];

    // Overall MDBList Score
    if (cfg.mdbListShowScore && _mdbListRatings!.overallScore != null) {
      widgets.add(
        _buildRatingBadge(
          'assets/logos/mdblist.svg',
          '${_mdbListRatings!.overallScore}%',
        ),
      );
    }

    // IMDb
    final imdb = _mdbListRatings!.getRating('imdb');
    if (cfg.mdbListShowImdb && imdb?.value != null) {
      widgets.add(_buildRatingBadge('assets/logos/imdb.svg', '${imdb!.value}'));
    }

    // Rotten Tomatoes
    final tomatoes = _mdbListRatings!.getRating('tomatoes');
    if (cfg.mdbListShowTomatoes && tomatoes?.value != null) {
      widgets.add(
        _buildRatingBadge('assets/logos/tomatoes.svg', '${tomatoes!.value}%'),
      );
    }

    // Metacritic
    final meta = _mdbListRatings!.getRating('metacritic');
    if (cfg.mdbListShowMetacritic && meta?.value != null) {
      widgets.add(
        _buildRatingBadge('assets/logos/metacritic.svg', '${meta!.value}/100'),
      );
    }

    // Letterboxd
    final letterboxd = _mdbListRatings!.getRating('letterboxd');
    if (cfg.mdbListShowLetterboxd && letterboxd?.value != null) {
      widgets.add(
        _buildRatingBadge(
          'assets/logos/letterboxd.svg',
          '${letterboxd!.value}',
        ),
      );
    }

    // Trakt
    final trakt = _mdbListRatings!.getRating('trakt');
    if (cfg.mdbListShowTrakt && trakt?.value != null) {
      widgets.add(
        _buildRatingBadge('assets/logos/trakt.svg', '${trakt!.value}%'),
      );
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RATINGS (MDBList)',
            style: TextStyle(
              color: Colors.white30,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: widgets),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(String svgPath, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(svgPath, width: 16, height: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildEpisodesPanel(bool isPortrait) {
    final seasons = _availableSeasons();
    final episodes = _availableEpisodes();

    final listWidget = AnimationLimiter(
      child: ListView.builder(
      shrinkWrap: isPortrait,
      physics: isPortrait ? const NeverScrollableScrollPhysics() : null,
      itemCount: episodes.length,
      itemBuilder: (context, idx) {
        final ep = episodes[idx];
        final isActive = _selectedVideoId == ep.id;

        return AnimationConfiguration.staggeredList(
          position: idx,
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: EpisodeCard(
                ep: ep,
                isActive: isActive,
                scale: SettingsService.instance.value.discoverScale,
                autofocus: idx == 0,
                onTap: () {
                  setState(() {
                    _selectedVideoId = ep.id;
                    _viewingStreams = true;
                  });
                  _fetchStreams(ep.id);
                  _fetchSubtitles(ep.id);
                },
              ),
            ),
          ),
        );
      },
    ),
    );

    return Column(
      children: [
        // Season Navigation Header
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: HorizontalScrollWrapper(
            child: Row(
              children: [
                for (final s in seasons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: AddonFilterTab(
                      title: s == 0 ? 'Specials' : 'Season $s',
                      isSelected: _selectedSeason == s,
                      onTap: () => setState(() => _selectedSeason = s),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Episodes list
        isPortrait ? listWidget : Expanded(child: listWidget),
      ],
    );
  }

  Widget _buildStreamsPanel(bool isPortrait) {
    final list = _filteredStreams();
    final addonNames = _streamAddons.map((a) => a.manifest.name).toList();
    if (addonNames.isEmpty && _uniqueAddons().isNotEmpty) {
      addonNames.addAll(_uniqueAddons());
    }

    Widget listWidget;
    if (list.isEmpty && _loadingAddonNames.isNotEmpty) {
      listWidget = ListView.builder(
        shrinkWrap: isPortrait,
        physics: isPortrait ? const NeverScrollableScrollPhysics() : null,
        itemCount: 3,
        itemBuilder: (context, idx) => _buildStreamSkeleton(),
      );
    } else if (list.isEmpty) {
      listWidget = Container(
        height: isPortrait ? 200 : null,
        alignment: Alignment.center,
        child: Text(
          _loadingAddonNames.isNotEmpty
              ? 'Searching for streams...'
              : 'No streams found. Check your active addons.',
          style: const TextStyle(color: Colors.white30),
        ),
      );
    } else {
      listWidget = AnimationLimiter(
        child: ListView.builder(
        shrinkWrap: isPortrait,
        physics: isPortrait ? const NeverScrollableScrollPhysics() : null,
        itemCount: list.length,
        itemBuilder: (context, idx) {
          final s = list[idx];
          final sKey =
              s.infoHash ??
              s.url ??
              s.externalUrl ??
              s.nzbUrl ??
              s.title ??
              s.hashCode.toString();
          final resolving = _resolvingHash != null && _resolvingHash == sKey;

          return AnimationConfiguration.staggeredList(
            position: idx,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: StreamCard(
                  stream: s,
                  resolving: resolving,
                  autofocus: idx == 0,
                  scale: SettingsService.instance.value.discoverScale,
                  onTap: () => _handleStream(s),
                  onDownload: () => _handleDownloadRequest(s),
                  onDelete: () => _deleteStream(s),
                ),
              ),
            ),
          );
        },
      ),
      );
    }

    String? epBadge;
    if (widget.type == "series") {
      MetaVideo? currentVid;
      if (_meta?.videos != null) {
        try {
          currentVid = _meta!.videos!.firstWhere(
            (v) => v.id == _selectedVideoId,
          );
        } catch (_) {}
      }
      if (currentVid?.season != null && currentVid?.episode != null) {
        epBadge = "S${currentVid!.season}E${currentVid!.episode}";
      } else if (_selectedVideoId.contains(':')) {
        final parts = _selectedVideoId.split(':');
        if (parts.length >= 3) {
          epBadge = "S${parts[1]}E${parts[2]}";
        }
      }
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.type == "series") ...[
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        size: 16,
                        color: Colors.white70,
                      ),
                      onPressed: () => setState(() => _viewingStreams = false),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Text(
                    'Available Streams',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (epBadge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        epBadge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${list.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              if (addonNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                HorizontalScrollWrapper(
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: AddonFilterTab(
                          title: 'All Addons',
                          count: _streams.length,
                          isLoading: _loadingAddonNames.isNotEmpty,
                          isSelected: _selectedAddon == 'all',
                          onTap: () => setState(() => _selectedAddon = 'all'),
                        ),
                      ),
                      for (final addonName in addonNames) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: AddonFilterTab(
                            title: addonName,
                            count: _addonStreamCounts[addonName],
                            isLoading: _loadingAddonNames.contains(addonName),
                            isSelected: _selectedAddon == addonName,
                            onTap: () =>
                                setState(() => _selectedAddon = addonName),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Streams List
        isPortrait ? listWidget : Expanded(child: listWidget),
      ],
    );
  }

  void _cleanupEmptyFolders(Directory dir, String baseDir) {
    if (dir.path == baseDir || !dir.existsSync()) return;
    
    try {
      final list = dir.listSync();
      bool hasImportantFiles = false;
      for (final f in list) {
        if (f is Directory) {
          hasImportantFiles = true;
          break;
        }
        if (f is File) {
          final p = f.path.toLowerCase();
          if (p.endsWith('.mp4') || p.endsWith('.mkv') || p.endsWith('.avi')) {
            hasImportantFiles = true;
            break;
          }
        }
      }
      
      if (!hasImportantFiles) {
        dir.deleteSync(recursive: true);
        _cleanupEmptyFolders(dir.parent, baseDir);
      }
    } catch (e) {
      // Ignore errors (e.g. permission denied)
    }
  }

  void _deleteStream(StreamModel stream) async {
    if (stream.url == null || !stream.url!.startsWith('file://')) return;
    
    // Better handling of Windows paths
    final path = Uri.parse(stream.url!).toFilePath();
    final file = File(path);
    if (file.existsSync()) {
      bool deleted = false;
      int retries = 5;
      
      while (retries > 0 && !deleted) {
        try {
          file.deleteSync();
          deleted = true;
          _showTopToast('File deleted.');
          
          final baseDir = SettingsService.instance.value.downloadPath;
          _cleanupEmptyFolders(file.parent, baseDir);
          
          // Reload streams list to remove the local file
          _loadOfflineStreams(widget.item.id ?? '');
        } catch (e) {
          if (e.toString().contains('used by another process') || e.toString().contains('errno = 32')) {
            // File still locked by the video player's async dispose. Wait and retry.
            retries--;
            if (retries > 0) {
              await Future.delayed(const Duration(milliseconds: 500));
            } else {
              _showTopToast('Error: File is still in use by the player. Try again in a moment.');
            }
          } else {
            // Unrelated error, show it immediately and stop retrying
            _showTopToast('Error deleting file: $e');
            break;
          }
        }
      }
    }
  }

  Widget _buildStreamSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildSkeleton(width: 36, height: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeleton(width: 80, height: 12),
                const SizedBox(height: 6),
                _buildSkeleton(width: double.infinity, height: 16),
                const SizedBox(height: 4),
                _buildSkeleton(width: 150, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StreamCard extends StatefulWidget {
  final StreamModel stream;
  final bool resolving;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final bool autofocus;
  final double scale;

  const StreamCard({
    super.key,
    required this.stream,
    required this.onTap,
    this.onDownload,
    this.onDelete,
    this.resolving = false,
    this.autofocus = false,
    this.scale = 1.0,
  });

  @override
  State<StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<StreamCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stream;
    final resolving = widget.resolving;

    // Parse badges from stream info
    final desc = s.description ?? s.title ?? "";
    final text = ("${s.name ?? ''} $desc").toLowerCase();
    final has4K = text.contains("4k") || text.contains("2160p");
    final hasDV = text.contains("dolby vision") || text.contains(" dv ");
    final hasHDR10 = text.contains("hdr10+");
    final hasHDR = !hasHDR10 && text.contains("hdr");
    final hasAtmos = text.contains("atmos");
    final hasDDP =
        text.contains("ddp") || text.contains("dd+") || text.contains("eac3");
    final hasDTS = text.contains("dts");
    final has51 = !hasAtmos && !hasDDP && !hasDTS && text.contains("5.1");

    // Format multiline stream description
    final lines = desc
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    return AnimatedScale(
      scale: _isFocused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isFocused
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
          color: _isFocused
              ? Colors.white.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: GestureDetector(
          onSecondaryTapDown: (details) {
            final isLocal = s.url != null && s.url!.startsWith('file://');
            
            if (isLocal && widget.onDelete != null) {
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                  details.globalPosition.dx,
                  details.globalPosition.dy,
                  details.globalPosition.dx,
                  details.globalPosition.dy,
                ),
                items: [
                  PopupMenuItem(
                    onTap: widget.onDelete,
                    child: const Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Text('Delete File', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              );
            } else if (!isLocal && widget.onDownload != null) {
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                  details.globalPosition.dx,
                  details.globalPosition.dy,
                  details.globalPosition.dx,
                  details.globalPosition.dy,
                ),
                items: [
                  PopupMenuItem(
                    onTap: widget.onDownload,
                    child: const Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 12),
                        Text('Download'),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
          child: InkWell(
            autofocus: widget.autofocus,
            onFocusChange: (val) => setState(() => _isFocused = val),
            onHover: (val) => setState(() => _isFocused = val),
            onTap: widget.onTap,
            onLongPress: widget.onDownload,
            borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0 * widget.scale,
              vertical: 12.0 * widget.scale,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Play icon / Spinner
                Container(
                  width: 36 * widget.scale,
                  height: 36 * widget.scale,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: resolving
                      ? SizedBox(
                          width: 24 * widget.scale,
                          height: 24 * widget.scale,
                          child: BrandLoadingIndicator(
                            size: 24 * widget.scale,
                            color: Colors.cyan,
                          ),
                        )
                      : Icon(
                          Icons.play_arrow,
                          color: Colors.white70,
                          size: 20 * widget.scale,
                        ),
                ),
                SizedBox(width: 16 * widget.scale),

                // Stream Title & Addon Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (s.name != null && s.name!.isNotEmpty)
                        Text(
                          s.name!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14 * widget.scale,
                          ),
                        )
                      else if (s.addonName != null)
                        Text(
                          s.addonName!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14 * widget.scale,
                          ),
                        ),
                      if (desc.isNotEmpty) ...[
                        SizedBox(height: 4 * widget.scale),
                        Text(
                          desc,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12 * widget.scale,
                            height: 1.4,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 16 * widget.scale),

                // Badges
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (has4K)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Badge4K(),
                      ),
                    if (hasDV)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: BadgeDV(),
                      ),
                    if (hasHDR10)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: BadgeHDR10(),
                      ),
                    if (hasHDR)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: BadgeHDR(),
                      ),
                    if (hasAtmos)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: BadgeAtmos(),
                      ),
                    if (hasDDP)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: BadgeDDP(),
                      ),
                    if (hasDTS)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: BadgeDTS(),
                      ),
                    if (has51)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Badge51(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}

class AddonFilterTab extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLoading;
  final int? count;

  const AddonFilterTab({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.isLoading = false,
    this.count,
  });

  @override
  State<AddonFilterTab> createState() => _AddonFilterTabState();
}

class _AddonFilterTabState extends State<AddonFilterTab> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.count != null
        ? '${widget.title} (${widget.count})'
        : widget.title;

    return AnimatedScale(
      scale: _isFocused ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          onFocusChange: (val) => setState(() => _isFocused = val),
          onHover: (val) => setState(() => _isFocused = val),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isFocused
                  ? Colors.white
                  : (widget.isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused
                    ? Colors.white
                    : (widget.isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayTitle,
                  style: TextStyle(
                    color: _isFocused
                        ? Colors.black
                        : (widget.isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white70),
                    fontWeight: _isFocused || widget.isSelected
                        ? FontWeight.bold
                        : FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                if (widget.isLoading) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: _isFocused
                          ? Colors.black
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EpisodeCard extends StatefulWidget {
  final MetaVideo ep;
  final bool isActive;
  final VoidCallback onTap;
  final bool autofocus;
  final double scale;

  const EpisodeCard({
    super.key,
    required this.ep,
    required this.isActive,
    required this.onTap,
    this.autofocus = false,
    this.scale = 1.0,
  });

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final ep = widget.ep;
    final isActive = widget.isActive;

    return AnimatedScale(
      scale: _isFocused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isFocused
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
          color: _isFocused || isActive
              ? Colors.white.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: InkWell(
          autofocus: widget.autofocus,
          onFocusChange: (val) => setState(() => _isFocused = val),
          onHover: (val) => setState(() => _isFocused = val),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0 * widget.scale,
              vertical: 8.0 * widget.scale,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ep.thumbnail != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: ep.thumbnail!.startsWith('file://')
                            ? Image.file(
                                File.fromUri(Uri.parse(ep.thumbnail!)),
                                width: 80 * widget.scale,
                                height: 45 * widget.scale,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const SizedBox(),
                              )
                            : WebSafeImage(
                                imageUrl: ep.thumbnail!,
                                width: 80 * widget.scale,
                                height: 45 * widget.scale,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                memCacheWidth: 400,
                              ),
                      )
                    : Container(
                        width: 80 * widget.scale,
                        height: 45 * widget.scale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${ep.episode}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${ep.episode}. ${ep.title.isNotEmpty ? ep.title : (ep.released ?? 'Episode ${ep.episode}')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14 * widget.scale,
                        ),
                      ),
                      if (ep.released != null ||
                          _DetailScreenState._hasValidRating(
                            ep.imdbRating,
                          )) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (ep.released != null)
                              Text(
                                ep.released!.split('T')[0],
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12 * widget.scale,
                                ),
                              ),
                            if (ep.released != null &&
                                _DetailScreenState._hasValidRating(
                                  ep.imdbRating,
                                ))
                              SizedBox(width: 8 * widget.scale),
                            if (_DetailScreenState._hasValidRating(
                              ep.imdbRating,
                            )) ...[
                              Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 12 * widget.scale,
                              ),
                              SizedBox(width: 4 * widget.scale),
                              Text(
                                ep.imdbRating!,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12 * widget.scale,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HorizontalScrollWrapper extends StatefulWidget {
  final Widget child;

  const HorizontalScrollWrapper({
    super.key,
    required this.child,
  });

  @override
  State<HorizontalScrollWrapper> createState() => _HorizontalScrollWrapperState();
}

class _HorizontalScrollWrapperState extends State<HorizontalScrollWrapper> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          if (pointerSignal.scrollDelta.dy != 0) {
            final targetOffset = _controller.offset + pointerSignal.scrollDelta.dy;
            _controller.jumpTo(
              targetOffset.clamp(
                0.0,
                _controller.position.maxScrollExtent,
              ),
            );
          }
        }
      },
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}

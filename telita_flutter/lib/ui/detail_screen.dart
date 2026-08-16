import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import '../core/addon_client.dart';
import '../core/settings.dart';
import '../core/mdblist_client.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import 'badges.dart';
import 'spinning_logo.dart';
class DetailScreen extends StatefulWidget {
  final MetaPreview item;
  final String type; // "movie" | "series"
  final String? initialVideoId;
  final VoidCallback onBack;
  final Function(
    String url,
    String type,
    String id, {
    Map<String, String>? headers,
    List<MediaSegment>? segments,
    MetaPreview? meta,
    List<MediaItemSubtitle>? subtitles,
  }) onPlay;

  const DetailScreen({
    super.key,
    required this.item,
    required this.type,
    this.initialVideoId,
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

    await AddonRegistry.instance.init();
    final m = await AddonRegistry.instance.getMeta(widget.type, widget.item.id);

    _loadMdbListRatings();

    if (mounted) {
      setState(() {
        _meta = m ?? widget.item;
        _loading = false;
      });
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
                targetVid = videos.firstWhere((v) => v.season == targetSeason && v.episode == targetEp);
              } catch (_) {}
            }
          }
        }
        targetVid ??= videos[0];

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

  Future<void> _fetchSubtitles(String videoId) async {
    setState(() {
      _subtitlesLoading = true;
      _subtitles = [];
    });
    try {
      final subs = await AddonRegistry.instance.getSubtitles(widget.type, videoId);
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
      AddonRegistry.instance.getStreamsFromAddon(addon, widget.type, videoId).then((newStreams) {
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
      }).catchError((e) {
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

  static bool _hasValidRating(String? rating) {
    if (rating == null || rating.trim().isEmpty) return false;
    final r = rating.trim();
    if (r == '0' || r == '0.0' || r == '0.00' || r == 'null') return false;
    final val = double.tryParse(r);
    return val != null && val > 0;
  }

  static Map<String, dynamic> _decodeJsonMap(String body) => jsonDecode(body) as Map<String, dynamic>;

  Future<String?> _resolveStreamUrl(String infoHash) async {
    try {
      final res = await http.get(
        Uri.parse("http://127.0.0.1:8081/api/play?infoHash=$infoHash"),
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

  Future<List<MediaSegment>?> _fetchSkipSegments(String videoId) async {
    final cfg = SettingsService.instance.value;
    if (!cfg.introSkipEnabled) {
      print('[INTROSKIP] Feature disabled in settings');
      return null;
    }

    final parts = videoId.split(':');
    final imdbId = parts.isNotEmpty ? parts[0] : videoId;
    final season = parts.length > 1 ? parts[1] : null;
    final episode = parts.length > 2 ? parts[2] : null;

    final primaryProvider = cfg.introSkipProvider;
    final secondaryProvider = primaryProvider == 'introdb.app' ? 'theintrodb.org' : 'introdb.app';

    print('[INTROSKIP] Fetching skip segments for ID: $videoId (imdb: $imdbId, season: $season, ep: $episode) using $primaryProvider');

    var segments = await _tryFetchSkipSegments(primaryProvider, imdbId, season, episode);

    if (segments == null) {
      print('[INTROSKIP] $primaryProvider failed or returned error. Falling back to $secondaryProvider');
      segments = await _tryFetchSkipSegments(secondaryProvider, imdbId, season, episode);
    }

    if (segments != null) {
      print('[INTROSKIP] segments retrieved (${segments.length} found):');
      for (var seg in segments) {
        print('  -> [${seg.type}] start: ${seg.startSec}s, end: ${seg.endSec}s');
      }
      return segments;
    }

    print('[INTROSKIP] segments retrieved (0 segments found)');
    return null;
  }

  Future<List<MediaSegment>?> _tryFetchSkipSegments(String provider, String imdbId, String? season, String? episode) async {
    try {
      if (provider == 'introdb.app') {
        String url = 'https://api.introdb.app/segments?imdb_id=$imdbId';
        if (season != null && episode != null) {
          url += '&season=$season&episode=$episode';
        }
        print('[INTROSKIP] Request URL ($provider): $url');
        final res = await http.get(Uri.parse(url));
        print('[INTROSKIP] Response HTTP status ($provider): ${res.statusCode}');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) {
            return data.map((json) {
              return MediaSegment.fromJson(json as Map<String, dynamic>, json['segment_type'] ?? 'unknown');
            }).toList();
          }
        }
      } else if (provider == 'theintrodb.org') {
        String url = 'https://api.theintrodb.org/v3/media?imdb_id=$imdbId';
        if (season != null && episode != null) {
          url += '&season=$season&episode=$episode';
        }
        print('[INTROSKIP] Request URL ($provider): $url');
        final res = await http.get(Uri.parse(url));
        print('[INTROSKIP] Response HTTP status ($provider): ${res.statusCode}');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final segments = <MediaSegment>[];
          if (data['intro'] != null) {
            for (var i in data['intro']) segments.add(MediaSegment.fromJson(i, 'intro'));
          }
          if (data['recap'] != null) {
            for (var r in data['recap']) segments.add(MediaSegment.fromJson(r, 'recap'));
          }
          if (data['credits'] != null) {
            for (var c in data['credits']) segments.add(MediaSegment.fromJson(c, 'credits'));
          }
          if (data['preview'] != null) {
            for (var p in data['preview']) segments.add(MediaSegment.fromJson(p, 'preview'));
          }
          return segments;
        }
      }
    } catch (e) {
      print('[INTROSKIP] Error fetching from $provider: $e');
    }
    return null;
  }

  void _handleStream(StreamModel stream) async {
    final subtitleQueryId = widget.type == "movie"
        ? widget.item.id
        : _selectedVideoId;
    final headers = stream.behaviorHints?.proxyHeaders?.request;

    final streamKey = stream.infoHash ?? stream.url ?? stream.externalUrl ?? stream.nzbUrl ?? stream.title ?? stream.hashCode.toString();

    // Show a loading indicator in the play button while resolving or launching player
    setState(() {
      _resolvingHash = streamKey;
    });

    List<MediaSegment>? segments;
    if (widget.type == "movie") {
      segments = await _fetchSkipSegments(widget.item.id);
    } else {
      segments = await _fetchSkipSegments(_selectedVideoId);
    }

    final mediaSubtitles = _subtitles.map((sub) {
      final langCode = sub.lang.isNotEmpty ? sub.lang : 'en';
      final addon = (sub.addonName != null && sub.addonName!.isNotEmpty) ? sub.addonName! : 'Addon';
      return MediaItemSubtitle(
        url: sub.url,
        language: langCode,
        label: addon,
      );
    }).toList();

    if (stream.url != null) {
      widget.onPlay(stream.url!, widget.type, subtitleQueryId, headers: headers, segments: segments, meta: _meta, subtitles: mediaSubtitles);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _resolvingHash = null);
      });
    } else if (stream.externalUrl != null) {
      if (mounted) setState(() => _resolvingHash = null);
      final uri = Uri.parse(stream.externalUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (stream.nzbUrl != null && stream.servers != null && stream.servers!.isNotEmpty) {
      final encodedUrl = Uri.encodeComponent(stream.nzbUrl!);
      final encodedServer = Uri.encodeComponent(stream.servers!.first);
      final playUrl = "http://127.0.0.1:8081/api/play/nzb?nzbUrl=$encodedUrl&server=$encodedServer";
      widget.onPlay(playUrl, widget.type, subtitleQueryId, segments: segments, meta: _meta, subtitles: mediaSubtitles);
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
        widget.onPlay(url, widget.type, subtitleQueryId, segments: segments, meta: _meta, subtitles: mediaSubtitles);
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
    list.sort();
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
              child: Opacity(
                opacity: 0.15,
                child: CachedNetworkImage(
                  imageUrl: backdropUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  errorWidget: (context, url, error) => const SizedBox(),
                ),
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
                      final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
                      final metadataColumn = Padding(
                        padding: EdgeInsets.symmetric(horizontal: isPortrait ? 16.0 : 32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  padding: const EdgeInsets.only(
                                    bottom: 20.0,
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: _meta!.logo!,
                                    height: 100,
                                    fit: BoxFit.contain,
                                    memCacheWidth: 400,
                                    alignment: Alignment.centerLeft,
                                    errorWidget: (context, url, error) =>
                                        Text(
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
                          ],
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
                            child: SingleChildScrollView(
                              child: metadataColumn,
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: contentPanel,
                          ),
                        ],
                      );
                    }
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
      final ratings = await MdbListClient.fetchRatings(widget.item.id, cfg.mdbListApiKey);
      if (mounted) {
        setState(() {
          _mdbListRatings = ratings;
        });
      }
    }
  }

  Widget _buildMdbListBadges() {
    final cfg = SettingsService.instance.value;
    if (!cfg.mdbListEnabled || _mdbListRatings == null || cfg.mdbListApiKey.isEmpty) return const SizedBox.shrink();

    final widgets = <Widget>[];

    // Overall MDBList Score
    if (cfg.mdbListShowScore && _mdbListRatings!.overallScore != null) {
      widgets.add(_buildRatingBadge('assets/logos/mdblist.svg', '${_mdbListRatings!.overallScore}%'));
    }

    // IMDb
    final imdb = _mdbListRatings!.getRating('imdb');
    if (cfg.mdbListShowImdb && imdb?.value != null) {
      widgets.add(_buildRatingBadge('assets/logos/imdb.svg', '${imdb!.value}'));
    }

    // Rotten Tomatoes
    final tomatoes = _mdbListRatings!.getRating('tomatoes');
    if (cfg.mdbListShowTomatoes && tomatoes?.value != null) {
      widgets.add(_buildRatingBadge('assets/logos/tomatoes.svg', '${tomatoes!.value}%'));
    }

    // Metacritic
    final meta = _mdbListRatings!.getRating('metacritic');
    if (cfg.mdbListShowMetacritic && meta?.value != null) {
      widgets.add(_buildRatingBadge('assets/logos/metacritic.svg', '${meta!.value}/100'));
    }

    // Letterboxd
    final letterboxd = _mdbListRatings!.getRating('letterboxd');
    if (cfg.mdbListShowLetterboxd && letterboxd?.value != null) {
      widgets.add(_buildRatingBadge('assets/logos/letterboxd.svg', '${letterboxd!.value}'));
    }

    // Trakt
    final trakt = _mdbListRatings!.getRating('trakt');
    if (cfg.mdbListShowTrakt && trakt?.value != null) {
      widgets.add(_buildRatingBadge('assets/logos/trakt.svg', '${trakt!.value}%'));
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widgets,
          ),
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
          SvgPicture.asset(
            svgPath,
            width: 16,
            height: 16,
          ),
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

    final listWidget = ListView.builder(
      shrinkWrap: isPortrait,
      physics: isPortrait ? const NeverScrollableScrollPhysics() : null,
      itemCount: episodes.length,
      itemBuilder: (context, idx) {
        final ep = episodes[idx];
        final isActive = _selectedVideoId == ep.id;

        return EpisodeCard(
          ep: ep,
          isActive: isActive,
          autofocus: idx == 0,
          onTap: () {
            setState(() {
              _selectedVideoId = ep.id;
              _viewingStreams = true;
            });
            _fetchStreams(ep.id);
            _fetchSubtitles(ep.id);
          },
        );
      },
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in seasons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: AddonFilterTab(
                      title: 'Season $s',
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
          _loadingAddonNames.isNotEmpty ? 'Searching for streams...' : 'No streams found. Check your active addons.',
          style: const TextStyle(color: Colors.white30),
        ),
      );
    } else {
      listWidget = ListView.builder(
        shrinkWrap: isPortrait,
        physics: isPortrait ? const NeverScrollableScrollPhysics() : null,
        itemCount: list.length,
        itemBuilder: (context, idx) {
          final s = list[idx];
          final sKey = s.infoHash ?? s.url ?? s.externalUrl ?? s.nzbUrl ?? s.title ?? s.hashCode.toString();
          final resolving = _resolvingHash != null && _resolvingHash == sKey;

          return StreamCard(
            stream: s,
            resolving: resolving,
            autofocus: idx == 0,
            onTap: () => _handleStream(s),
          );
        },
      );
    }

    String? epBadge;
    if (widget.type == "series") {
      MetaVideo? currentVid;
      if (_meta?.videos != null) {
        try {
          currentVid = _meta!.videos!.firstWhere((v) => v.id == _selectedVideoId);
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
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
                            onTap: () => setState(() => _selectedAddon = addonName),
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
  final bool autofocus;

  const StreamCard({
    super.key,
    required this.stream,
    required this.resolving,
    this.onTap,
    this.autofocus = false,
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
    final lines = desc.split('\n').where((line) => line.trim().isNotEmpty).toList();

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
        child: InkWell(
          autofocus: widget.autofocus,
          onFocusChange: (val) => setState(() => _isFocused = val),
          onHover: (val) => setState(() => _isFocused = val),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Play icon / Spinner
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: resolving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: BrandLoadingIndicator(size: 24, color: Colors.cyan),
                        )
                      : const Icon(
                          Icons.play_arrow,
                          color: Colors.white70,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 16),

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
                            fontSize: 14,
                          ),
                        )
                      else if (s.addonName != null)
                        Text(
                          s.addonName!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Badges
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (has4K) const Padding(padding: EdgeInsets.only(bottom: 4), child: Badge4K()),
                    if (hasDV) const Padding(padding: EdgeInsets.only(bottom: 4), child: BadgeDV()),
                    if (hasHDR10) const Padding(padding: EdgeInsets.only(bottom: 4), child: BadgeHDR10()),
                    if (hasHDR) const Padding(padding: EdgeInsets.only(bottom: 4), child: BadgeHDR()),
                    if (hasAtmos) const Padding(padding: EdgeInsets.only(bottom: 4), child: BadgeAtmos()),
                    if (hasDDP) const Padding(padding: EdgeInsets.only(bottom: 4), child: BadgeDDP()),
                    if (hasDTS) const Padding(padding: EdgeInsets.only(bottom: 4), child: BadgeDTS()),
                    if (has51) const Padding(padding: EdgeInsets.only(bottom: 4), child: Badge51()),
                  ],
                ),
              ],
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
    final displayTitle = widget.count != null ? '${widget.title} (${widget.count})' : widget.title;

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
                  : (widget.isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused 
                    ? Colors.white 
                    : (widget.isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayTitle,
                  style: TextStyle(
                    color: _isFocused ? Colors.black : (widget.isSelected ? Theme.of(context).colorScheme.primary : Colors.white70),
                    fontWeight: _isFocused || widget.isSelected ? FontWeight.bold : FontWeight.w600,
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
                      color: _isFocused ? Colors.black : Theme.of(context).colorScheme.primary,
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

  const EpisodeCard({
    super.key,
    required this.ep,
    required this.isActive,
    required this.onTap,
    this.autofocus = false,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ep.thumbnail != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: ep.thumbnail!,
                          width: 80,
                          height: 45,
                          fit: BoxFit.cover,
                          memCacheWidth: 150,
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 45,
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
                          color: isActive ? Theme.of(context).colorScheme.primary : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (ep.released != null || _DetailScreenState._hasValidRating(ep.imdbRating)) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (ep.released != null)
                              Text(
                                ep.released!.split('T')[0],
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            if (ep.released != null && _DetailScreenState._hasValidRating(ep.imdbRating))
                              const SizedBox(width: 8),
                            if (_DetailScreenState._hasValidRating(ep.imdbRating)) ...[
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                ep.imdbRating!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ]
                          ],
                        )
                      ]
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

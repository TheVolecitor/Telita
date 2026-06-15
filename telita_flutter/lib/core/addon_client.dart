import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'auth.dart';

Map<String, dynamic> _decodeJsonMap(String body) => jsonDecode(body) as Map<String, dynamic>;
List<dynamic> _decodeJsonList(String body) => jsonDecode(body) as List<dynamic>;

class ManifestCatalog {
  final String type;
  final String id;
  final String? name;
  final List<dynamic>? extra;

  ManifestCatalog({required this.type, required this.id, this.name, this.extra});

  factory ManifestCatalog.fromJson(Map<String, dynamic> json) {
    return ManifestCatalog(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      name: json['name'],
      extra: json['extra'],
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        if (name != null) 'name': name,
        if (extra != null) 'extra': extra,
      };
}

class ManifestResource {
  final String name;
  final List<String>? types;
  final List<String>? idPrefixes;

  ManifestResource({required this.name, this.types, this.idPrefixes});

  factory ManifestResource.fromJson(dynamic json) {
    if (json is String) {
      return ManifestResource(name: json);
    }
    return ManifestResource(
      name: json['name'] ?? '',
      types: json['types'] != null ? List<String>.from(json['types']) : null,
      idPrefixes: json['idPrefixes'] != null ? List<String>.from(json['idPrefixes']) : null,
    );
  }

  dynamic toJson() {
    if (types == null && idPrefixes == null) return name;
    return {
      'name': name,
      if (types != null) 'types': types,
      if (idPrefixes != null) 'idPrefixes': idPrefixes,
    };
  }
}

class AddonManifest {
  final String id;
  final String name;
  final String description;
  final String version;
  final List<dynamic> resources;
  final List<String> types;
  final List<String>? idPrefixes;
  final List<ManifestCatalog> catalogs;
  final String? logo;
  final String? background;
  final Map<String, dynamic>? behaviorHints;

  AddonManifest({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.resources,
    required this.types,
    this.idPrefixes,
    required this.catalogs,
    this.logo,
    this.background,
    this.behaviorHints,
  });

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    return AddonManifest(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      version: json['version'] ?? '',
      resources: json['resources'] ?? [],
      types: List<String>.from(json['types'] ?? []),
      idPrefixes: json['idPrefixes'] != null ? List<String>.from(json['idPrefixes']) : null,
      catalogs: (json['catalogs'] as List?)?.map((e) => ManifestCatalog.fromJson(e)).toList() ?? [],
      logo: json['logo'],
      background: json['background'],
      behaviorHints: json['behaviorHints'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'resources': resources,
        'types': types,
        if (idPrefixes != null) 'idPrefixes': idPrefixes,
        'catalogs': catalogs.map((e) => e.toJson()).toList(),
        if (logo != null) 'logo': logo,
        if (background != null) 'background': background,
        if (behaviorHints != null) 'behaviorHints': behaviorHints,
      };
}

class InstalledAddon {
  final AddonManifest manifest;
  final String transportUrl;
  final bool installed;

  InstalledAddon({required this.manifest, required this.transportUrl, this.installed = true});

  factory InstalledAddon.fromJson(Map<String, dynamic> json) {
    return InstalledAddon(
      manifest: AddonManifest.fromJson(json['manifest']),
      transportUrl: json['transportUrl'],
      installed: json['installed'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'manifest': manifest.toJson(),
        'transportUrl': transportUrl,
        'installed': installed,
      };
}

class MetaVideo {
  final String id;
  final String title;
  final int? season;
  final int? episode;
  final String? released;
  final String? thumbnail;

  MetaVideo({
    required this.id,
    required this.title,
    this.season,
    this.episode,
    this.released,
    this.thumbnail,
  });

  factory MetaVideo.fromJson(Map<String, dynamic> json) {
    return MetaVideo(
      id: json['id'] ?? '',
      title: json['name'] ?? json['title'] ?? '',
      season: json['season'],
      episode: json['episode'],
      released: json['released'],
      thumbnail: json['thumbnail'] ?? json['tvdb_thumbnail'],
    );
  }
}

class MetaPreview {
  final String id;
  final String type;
  final String name;
  final String? poster;
  final String? background;
  final String? description;
  final String? releaseInfo;
  final String? imdbRating;
  final List<String>? genres;
  final String? logo;
  final String? runtime;
  final List<String>? cast;
  final List<MetaVideo>? videos;

  MetaPreview({
    required this.id,
    required this.type,
    required this.name,
    this.poster,
    this.background,
    this.description,
    this.releaseInfo,
    this.imdbRating,
    this.genres,
    this.logo,
    this.runtime,
    this.cast,
    this.videos,
  });

  factory MetaPreview.fromJson(Map<String, dynamic> json) {
    return MetaPreview(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      poster: json['poster'],
      background: json['background'],
      description: json['description'],
      releaseInfo: json['releaseInfo'] ?? json['year'],
      imdbRating: json['imdbRating'],
      genres: json['genres'] != null ? List<String>.from(json['genres']) : null,
      logo: json['logo'],
      runtime: json['runtime'],
      cast: json['cast'] != null ? List<String>.from(json['cast']) : null,
      videos: json['videos'] != null
          ? (json['videos'] as List).map((e) => MetaVideo.fromJson(e)).toList()
          : null,
    );
  }
}

class SearchResultGroup {
  final String addonName;
  final String catalogName;
  final List<MetaPreview> results;

  SearchResultGroup({required this.addonName, required this.catalogName, required this.results});
}

class StreamModel {
  final String? name;
  final String? description;
  final String? title;
  final String? url;
  final String? externalUrl;
  final String? ytId;
  final String? infoHash;
  final int? fileIdx;
  final String? addonName;

  StreamModel({
    this.name,
    this.description,
    this.title,
    this.url,
    this.externalUrl,
    this.ytId,
    this.infoHash,
    this.fileIdx,
    this.addonName,
  });

  factory StreamModel.fromJson(Map<String, dynamic> json, {String? addonName}) {
    return StreamModel(
      name: json['name'],
      description: json['description'] ?? json['title'],
      title: json['title'],
      url: json['url'],
      externalUrl: json['externalUrl'],
      ytId: json['ytId'],
      infoHash: json['infoHash'],
      fileIdx: json['fileIdx'],
      addonName: addonName,
    );
  }
}

class Subtitle {
  final String id;
  final String url;
  final String lang;

  Subtitle({required this.id, required this.url, required this.lang});

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      lang: json['lang'] ?? '',
    );
  }
}

class AddonRegistry {
  static const String _storageKey = "telita_installed_addons";
  static final List<String> _defaultAddonUrls = [
    "https://v3-cinemeta.strem.io/manifest.json",
    "https://opensubtitles-v3.strem.io/manifest.json",
  ];

  List<InstalledAddon> _addons = [];
  bool _initialized = false;
  Future<void>? _initFuture;

  static final AddonRegistry instance = AddonRegistry._internal();
  AddonRegistry._internal();

  Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    _initFuture = _doInit();
    await _initFuture;
    _initialized = true;
    _initFuture = null;
  }

  Future<void> _doInit() async {

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored != null) {
      try {
        final List<dynamic> decoded = await compute(_decodeJsonList, stored);
        _addons = decoded.map((e) => InstalledAddon.fromJson(e)).toList();
      } catch (e) {
        print("Error reading stored addons: \$e");
      }
    }

    for (final url in _defaultAddonUrls) {
      final expectedTransport = url.replaceAll(RegExp(r'/manifest\.json$'), "");
      final exists = _addons.any((a) => a.transportUrl == expectedTransport);
      if (!exists) {
        try {
          await install(url);
        } catch (e) {
          print("Failed to install default addon $url: $e");
        }
      }
    }

    AuthService.instance.addListener(() {
      if (AuthService.instance.value.token != null) {
        syncFromServer();
      }
    });
    if (AuthService.instance.value.token != null) {
      syncFromServer();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_addons.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
    _syncToServer();
  }

  Future<void> _syncToServer() async {
    if (AuthService.instance.value.token == null) return;
    try {
      final payload = {
        'addons': _addons.asMap().entries.map((e) {
          final addon = e.value;
          final manifestUrl = addon.transportUrl.endsWith('/manifest.json') 
            ? addon.transportUrl 
            : '${addon.transportUrl}/manifest.json';
          return {
            'manifest_url': manifestUrl,
            'position': e.key,
          };
        }).toList()
      };
      
      await http.post(
        Uri.parse('$defaultApiUrl/api/sync/addons'),
        headers: {
          'Authorization': 'Bearer ${AuthService.instance.value.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      print('Failed to sync addons to server: $e');
    }
  }

  bool _syncing = false;

  Future<void> syncFromServer() async {
    if (AuthService.instance.value.token == null) return;
    if (_syncing) return;
    _syncing = true;
    try {
      final res = await http.get(
        Uri.parse('$defaultApiUrl/api/sync/addons'),
        headers: {'Authorization': 'Bearer ${AuthService.instance.value.token}'},
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        if (data.isEmpty) return; // if server has no addons, we just keep local defaults
        
        // We will install/update all server addons, preserving order
        // Sort them by position first just in case
        data.sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
        
        // Let's clear our list and rebuild it by fetching from manifest URLs
        List<InstalledAddon> newAddons = [];
        for (final item in data) {
          final url = item['manifest_url'] as String;
          final expectedTransport = url.replaceAll(RegExp(r'/manifest\.json$'), "");
          // check if we already have it locally to avoid refetching
          final existing = _addons.where((a) => a.transportUrl == expectedTransport).firstOrNull;
          if (existing != null) {
            newAddons.add(existing);
          } else {
            try {
              final uri = Uri.parse(url);
              final req = await http.get(uri).timeout(const Duration(seconds: 10));
              if (req.statusCode == 200) {
                final manifestJson = await compute(_decodeJsonMap, req.body);
                final manifest = AddonManifest.fromJson(manifestJson);
                newAddons.add(InstalledAddon(manifest: manifest, transportUrl: expectedTransport, installed: true));
              }
            } catch (e) {
              print('Failed to fetch addon manifest $url during sync: $e');
            }
          }
        }
        
        if (newAddons.isNotEmpty) {
          _addons = newAddons;
          
          // Re-add any default addons that the user might not have on their server account yet
          for (final url in _defaultAddonUrls) {
            final expectedTransport = url.replaceAll(RegExp(r'/manifest\.json$'), "");
            if (!_addons.any((a) => a.transportUrl == expectedTransport)) {
              try {
                final uri = Uri.parse(url);
                final req = await http.get(uri).timeout(const Duration(seconds: 10));
                if (req.statusCode == 200) {
                  final manifestJson = await compute(_decodeJsonMap, req.body);
                  final manifest = AddonManifest.fromJson(manifestJson);
                  _addons.add(InstalledAddon(manifest: manifest, transportUrl: expectedTransport, installed: true));
                }
              } catch (_) {}
            }
          }

          // Save locally but DON'T trigger _syncToServer again to avoid loop
          final prefs = await SharedPreferences.getInstance();
          final encoded = jsonEncode(_addons.map((e) => e.toJson()).toList());
          await prefs.setString(_storageKey, encoded);
        }
      }
    } catch (e) {
      print('Failed to sync addons from server: $e');
    } finally {
      _syncing = false;
    }
  }

  List<InstalledAddon> getAll() => _addons;

  List<InstalledAddon> getInstalled() => _addons.where((a) => a.installed).toList();

  Future<InstalledAddon> install(String manifestUrl) async {
    final uri = Uri.parse(manifestUrl);
    final res = await http.get(uri).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw Exception("Failed to fetch manifest: ${res.statusCode}");

    final Map<String, dynamic> manifestJson = await compute(_decodeJsonMap, res.body);
    final manifest = AddonManifest.fromJson(manifestJson);
    if (manifest.id.isEmpty || manifest.name.isEmpty) throw Exception("Invalid Stremio addon manifest");

    final transportUrl = manifestUrl.replaceAll(RegExp(r'/manifest\.json$'), "");
    final existingIndex = _addons.indexWhere((a) => a.manifest.id == manifest.id);

    final addon = InstalledAddon(manifest: manifest, transportUrl: transportUrl, installed: true);
    if (existingIndex >= 0) {
      _addons[existingIndex] = addon;
    } else {
      _addons.add(addon);
    }
    await save();
    return addon;
  }

  void uninstall(String addonId) {
    _addons = _addons.map((a) {
      if (a.manifest.id == addonId) {
        return InstalledAddon(manifest: a.manifest, transportUrl: a.transportUrl, installed: false);
      }
      return a;
    }).toList();
    save();
  }

  void remove(String addonId) {
    _addons.removeWhere((a) => a.manifest.id == addonId);
    save();
  }

  void reorder(int startIndex, int endIndex) {
    if (startIndex < 0 || startIndex >= _addons.length || endIndex < 0 || endIndex >= _addons.length) return;
    final item = _addons.removeAt(startIndex);
    _addons.insert(endIndex, item);
    save();
  }

  ManifestResource? _resourceDef(InstalledAddon addon, String resourceName) {
    for (final r in addon.manifest.resources) {
      final res = ManifestResource.fromJson(r);
      if (res.name == resourceName) {
        return res;
      }
    }
    return null;
  }

  bool _supportsResource(InstalledAddon addon, String resourceName, String type, String id) {
    final def = _resourceDef(addon, resourceName);
    if (def == null) return false;
    if (def.types != null && !def.types!.contains(type)) return false;
    if (def.idPrefixes != null && def.idPrefixes!.isNotEmpty) {
      if (!def.idPrefixes!.any((p) => id.startsWith(p))) return false;
    }
    return true;
  }

  List<CatalogSource> getCatalogSources({String? type}) {
    final results = <CatalogSource>[];
    for (final addon in getInstalled()) {
      if (_resourceDef(addon, "catalog") == null) continue;
      for (final cat in addon.manifest.catalogs) {
        if (type != null && cat.type != type) continue;
        results.add(CatalogSource(addon: addon, catalog: cat));
      }
    }
    return results;
  }

  Future<List<MetaPreview>> fetchCatalog(InstalledAddon addon, ManifestCatalog catalog, {Map<String, String>? extra}) async {
    var url = "${addon.transportUrl}/catalog/${catalog.type}/${catalog.id}";
    if (extra != null && extra.isNotEmpty) {
      final extraStr = extra.entries.map((e) => "${e.key}=${Uri.encodeComponent(e.value)}").join("&");
      url += "/$extraStr";
    }
    url += ".json";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return [];
      final data = await compute(_decodeJsonMap, res.body);
      if (data['metas'] != null) {
        return (data['metas'] as List).map((e) => MetaPreview.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error fetching catalog: $e");
    }
    return [];
  }

  Future<List<SearchResultGroup>> search(String query) async {
    final groups = <SearchResultGroup>[];
    for (final addon in getInstalled()) {
      if (_resourceDef(addon, "catalog") == null) continue;
      for (final cat in addon.manifest.catalogs) {
        final supportsSearch = cat.extra?.any((e) => e['name'] == 'search') ?? false;
        if (!supportsSearch) continue;
        final results = await fetchCatalog(addon, cat, extra: {'search': query});
        if (results.isNotEmpty) {
          final typeLabel = cat.type == 'movie'
              ? 'Movies'
              : cat.type == 'series'
                  ? 'Series'
                  : (cat.type.substring(0, 1).toUpperCase() + cat.type.substring(1));
          groups.add(SearchResultGroup(
            addonName: addon.manifest.name,
            catalogName: "${cat.name ?? cat.id} - $typeLabel",
            results: results,
          ));
        }
      }
    }
    return groups;
  }

  Future<MetaPreview?> getMeta(String type, String id) async {
    for (final addon in getInstalled()) {
      if (!_supportsResource(addon, "meta", type, id)) continue;
      try {
        final url = "${addon.transportUrl}/meta/$type/$id.json";
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) continue;
        final data = await compute(_decodeJsonMap, res.body);
        if (data['meta'] != null) {
          return MetaPreview.fromJson(data['meta']);
        }
      } catch (e) {
        print("Error getting meta: $e");
      }
    }
    return null;
  }

  Future<List<StreamModel>> getStreams(String type, String id) async {
    final addons = getInstalled();
    final results = await Future.wait(addons.map((addon) async {
      if (!_supportsResource(addon, "stream", type, id)) return <StreamModel>[];
      try {
        final url = "${addon.transportUrl}/stream/$type/$id.json";
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) return <StreamModel>[];
        final data = await compute(_decodeJsonMap, res.body);
        final List<dynamic> streams = data['streams'] ?? [];
        return streams.map((s) => StreamModel.fromJson(s, addonName: addon.manifest.name)).toList();
      } catch (e) {
        print("Error getting streams: $e");
        return <StreamModel>[];
      }
    }));
    return results.expand((x) => x).toList();
  }

  Future<List<Subtitle>> getSubtitles(String type, String id) async {
    final all = <Subtitle>[];
    await Future.wait(getInstalled().map((addon) async {
      if (!_supportsResource(addon, "subtitles", type, id)) return;
      try {
        final url = "${addon.transportUrl}/subtitles/$type/$id.json";
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) return;
        final data = await compute(_decodeJsonMap, res.body);
        final List<dynamic> subs = data['subtitles'] ?? [];
        all.addAll(subs.map((s) => Subtitle.fromJson(s)));
      } catch (e) {
        print("Error getting subtitles: $e");
      }
    }));
    return all;
  }
}

class CatalogSource {
  final InstalledAddon addon;
  final ManifestCatalog catalog;

  CatalogSource({required this.addon, required this.catalog});
}

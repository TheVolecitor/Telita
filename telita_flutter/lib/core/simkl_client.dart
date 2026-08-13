import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'addon_client.dart';

class SimklClient {
  static const String _baseUrl = 'https://api.simkl.com';
  
  // User provided Telita Simkl Client ID
  static const String defaultClientId = 'ba35751d811771b82cf3ca7f6317d3fb311ee3def92c45322cadc836016cbb13';

  /// Get effective Client ID
  static String getEffectiveClientId(String? customId) {
    if (customId != null && customId.trim().isNotEmpty) {
      return customId.trim();
    }
    return defaultClientId;
  }

  /// Request a new Device Code / PIN from Simkl (Device Flow)
  static Future<Map<String, dynamic>> requestDevicePin({String? customClientId}) async {
    final clientId = getEffectiveClientId(customClientId);
    try {
      final url = '$_baseUrl/oauth/pin?client_id=$clientId';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final userCode = data['user_code'] as String?;
        final verificationUrl = data['verification_url'] as String? ?? (userCode != null ? 'https://simkl.com/pin/$userCode' : 'https://simkl.com/pin');
        final expiresIn = (data['expires_in'] ?? 900) as int;
        final interval = (data['interval'] ?? 5) as int;
        return {
          'success': true,
          'user_code': userCode,
          'verification_url': verificationUrl,
          'expires_in': expiresIn,
          'interval': interval,
        };
      }
      return {'success': false, 'error': 'HTTP ${res.statusCode}: ${res.body}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Poll / check if the user authorized the Device PIN on Simkl
  static Future<Map<String, dynamic>> checkDevicePinStatus({
    required String userCode,
    String? customClientId,
  }) async {
    final clientId = getEffectiveClientId(customClientId);
    try {
      final url = '$_baseUrl/oauth/pin/$userCode?client_id=$clientId';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final result = data['result'] as String?;
        final token = data['access_token'] as String?;

        if (result == 'OK' && token != null && token.isNotEmpty) {
          final username = await fetchUsername(token: token, clientId: clientId);
          return {
            'success': true,
            'authorized': true,
            'access_token': token,
            'username': username ?? 'Simkl User',
          };
        } else if (result == 'pending' || result == 'KO' || token == null) {
          return {
            'success': true,
            'authorized': false,
          };
        }
      }
      return {'success': false, 'error': 'HTTP ${res.statusCode}: ${res.body}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Map<String, String> _headers(String? token, String clientId) {
    return {
      'Content-Type': 'application/json',
      'User-Agent': 'Telita/1.0.0 (Windows; Flutter)',
      'simkl-api-key': clientId,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static String _buildUrl(String path, String clientId, [Map<String, String>? extraParams]) {
    final query = {
      'client_id': clientId,
      'app-name': 'Telita',
      'app-version': '1.0.0',
      if (extraParams != null) ...extraParams,
    };
    final queryString = query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$_baseUrl$path?$queryString';
  }

  /// Fetch Simkl user profile username
  static Future<String?> fetchUsername({
    required String token,
    required String clientId,
  }) async {
    try {
      final url = _buildUrl('/users/settings', clientId);
      final res = await http.get(
        Uri.parse(url),
        headers: _headers(token, clientId),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>?;
        return user?['name'] as String? ?? user?['username'] as String?;
      }
    } catch (e) {
      print('Simkl fetchUsername error: $e');
    }
    return null;
  }

  /// Scrobble watched media item to Simkl history
  static Future<bool> scrobbleWatched({
    required String type, // "movie" | "series"
    required String title,
    required String contentId, // e.g. "tt1234567" or "tt0903747:1:2"
  }) async {
    final cfg = SettingsService.instance.value;
    if (!cfg.simklEnabled || cfg.simklAccessToken.isEmpty) {
      return false;
    }

    final effClientId = getEffectiveClientId(cfg.simklClientId);

    try {
      Map<String, dynamic> body = {};

      if (type == 'movie') {
        final imdbId = contentId.split(':')[0];
        body = {
          'movies': [
            {
              'title': title,
              'ids': {'imdb': imdbId},
            }
          ]
        };
      } else {
        final parts = contentId.split(':');
        final imdbId = parts[0];
        final season = parts.length >= 2 ? int.tryParse(parts[1]) ?? 1 : 1;
        final episode = parts.length >= 3 ? int.tryParse(parts[2]) ?? 1 : 1;

        body = {
          'shows': [
            {
              'title': title,
              'ids': {'imdb': imdbId},
              'seasons': [
                {
                  'number': season,
                  'episodes': [
                    {'number': episode}
                  ]
                }
              ]
            }
          ]
        };
      }

      final url = _buildUrl('/sync/history', effClientId);
      final res = await http.post(
        Uri.parse(url),
        headers: _headers(cfg.simklAccessToken, effClientId),
        body: jsonEncode(body),
      );

      print('Simkl scrobble status: ${res.statusCode} -> ${res.body}');
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      print('Simkl scrobble error: $e');
      return false;
    }
  }

  /// Helper to convert Simkl JSON item to MetaPreview
  static MetaPreview? _parseSimklItem(Map<String, dynamic> item) {
    Map<String, dynamic>? metaObj;
    String type = 'series';

    if (item.containsKey('show')) {
      metaObj = item['show'] as Map<String, dynamic>?;
      type = 'series';
    } else if (item.containsKey('movie')) {
      metaObj = item['movie'] as Map<String, dynamic>?;
      type = 'movie';
    } else if (item.containsKey('anime')) {
      metaObj = item['anime'] as Map<String, dynamic>?;
      type = 'series';
    } else {
      metaObj = item;
    }

    if (metaObj == null) return null;

    final ids = metaObj['ids'] as Map<String, dynamic>?;
    final imdbId = ids?['imdb'] as String? ?? (ids?['simkl'] != null ? 'simkl_${ids!['simkl']}' : null);
    final title = metaObj['title'] as String? ?? 'Unknown';
    final posterPath = metaObj['poster'] as String?;

    if (imdbId == null || imdbId.isEmpty) return null;

    String? posterUrl;
    if (posterPath != null && posterPath.isNotEmpty) {
      if (posterPath.startsWith('http')) {
        posterUrl = posterPath;
      } else {
        posterUrl = 'https://simkl.in/posters/${posterPath}_m.jpg';
      }
    }

    return MetaPreview(
      id: imdbId,
      type: type,
      name: title,
      poster: posterUrl,
    );
  }

  /// Sync Simkl Watchlists using official 2-Phase Strategy & Activity timestamps
  static Future<Map<String, List<MetaPreview>>> fetchWatchlistCatalogs({bool forceRefresh = false}) async {
    final cfg = SettingsService.instance.value;
    if (!cfg.simklEnabled || cfg.simklAccessToken.isEmpty) {
      return {};
    }

    final effClientId = getEffectiveClientId(cfg.simklClientId);
    final prefs = await SharedPreferences.getInstance();

    final savedActivityDate = prefs.getString('simkl_last_activity_date');
    final lastCheckTime = prefs.getInt('simkl_last_check_time') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Check cached items
    final cachedWatchingRaw = prefs.getString('simkl_cache_watching');
    final cachedPlanRaw = prefs.getString('simkl_cache_plantowatch');
    final cachedCompletedRaw = prefs.getString('simkl_cache_completed');

    bool hasCache = cachedWatchingRaw != null || cachedPlanRaw != null || cachedCompletedRaw != null;

    // Throttle activity checks to once every 15 mins (900,000 ms) unless forceRefresh is set
    if (!forceRefresh && hasCache && (nowMs - lastCheckTime < 15 * 60 * 1000)) {
      return _decodeWatchlistsFromCache(prefs);
    }

    try {
      // Step 1: Check Activities endpoint first
      final actUrl = _buildUrl('/sync/activities', effClientId);
      final actRes = await http.get(
        Uri.parse(actUrl),
        headers: _headers(cfg.simklAccessToken, effClientId),
      );

      String? latestActivityDate;
      if (actRes.statusCode == 200) {
        final actData = jsonDecode(actRes.body) as Map<String, dynamic>;
        latestActivityDate = actData['all_items'] as String? ?? actData['shows'] as String?;
      }

      await prefs.setInt('simkl_last_check_time', nowMs);

      // If timestamps match and cache exists, skip downloading!
      if (!forceRefresh && hasCache && savedActivityDate != null && latestActivityDate == savedActivityDate) {
        print('Simkl activities match ($savedActivityDate). Using cached watchlists.');
        return _decodeWatchlistsFromCache(prefs);
      }

      List<MetaPreview> watchingList = [];
      List<MetaPreview> planList = [];
      List<MetaPreview> completedList = [];

      if (savedActivityDate == null || forceRefresh || !hasCache) {
        // PHASE 1: Initial Sync (Fetch libraries sequentially to avoid CPU spikes)
        print('Simkl Phase 1: Sequential Initial Sync...');

        // 1. Fetch Shows
        final showsUrl = _buildUrl('/sync/shows', effClientId);
        final showsRes = await http.get(Uri.parse(showsUrl), headers: _headers(cfg.simklAccessToken, effClientId));
        if (showsRes.statusCode == 200) {
          final data = jsonDecode(showsRes.body);
          if (data is Map<String, dynamic> && data.containsKey('shows')) {
            _categorizeSimklItems(data['shows'] as List<dynamic>, watchingList, planList, completedList);
          }
        }

        await Future.delayed(const Duration(milliseconds: 150));

        // 2. Fetch Movies
        final moviesUrl = _buildUrl('/sync/movies', effClientId);
        final moviesRes = await http.get(Uri.parse(moviesUrl), headers: _headers(cfg.simklAccessToken, effClientId));
        if (moviesRes.statusCode == 200) {
          final data = jsonDecode(moviesRes.body);
          if (data is Map<String, dynamic> && data.containsKey('movies')) {
            _categorizeSimklItems(data['movies'] as List<dynamic>, watchingList, planList, completedList);
          }
        }

        await Future.delayed(const Duration(milliseconds: 150));

        // 3. Fetch Anime
        final animeUrl = _buildUrl('/sync/anime', effClientId);
        final animeRes = await http.get(Uri.parse(animeUrl), headers: _headers(cfg.simklAccessToken, effClientId));
        if (animeRes.statusCode == 200) {
          final data = jsonDecode(animeRes.body);
          if (data is Map<String, dynamic> && data.containsKey('anime')) {
            _categorizeSimklItems(data['anime'] as List<dynamic>, watchingList, planList, completedList);
          }
        }
      } else {
        // PHASE 2: Delta Sync (/sync/all-items/?date_from=SAVED_DATE)
        print('Simkl Phase 2: Delta Sync with date_from=$savedActivityDate');
        final deltaUrl = _buildUrl('/sync/all-items/', effClientId, {'date_from': savedActivityDate});
        final deltaRes = await http.get(Uri.parse(deltaUrl), headers: _headers(cfg.simklAccessToken, effClientId));

        // Read existing cache first
        final existing = _decodeWatchlistsFromCache(prefs);
        watchingList = existing['watching'] ?? [];
        planList = existing['plantowatch'] ?? [];
        completedList = existing['completed'] ?? [];

        if (deltaRes.statusCode == 200) {
          final data = jsonDecode(deltaRes.body) as Map<String, dynamic>;
          for (final key in ['shows', 'movies', 'anime']) {
            if (data.containsKey(key) && data[key] is List) {
              _categorizeSimklItems(data[key] as List<dynamic>, watchingList, planList, completedList);
            }
          }
        }
      }

      // Save new activity date & cache
      if (latestActivityDate != null) {
        await prefs.setString('simkl_last_activity_date', latestActivityDate);
      }

      await prefs.setString('simkl_cache_watching', jsonEncode(watchingList.map((e) => e.toJson()).toList()));
      await prefs.setString('simkl_cache_plantowatch', jsonEncode(planList.map((e) => e.toJson()).toList()));
      await prefs.setString('simkl_cache_completed', jsonEncode(completedList.map((e) => e.toJson()).toList()));

      return {
        'watching': watchingList,
        'plantowatch': planList,
        'completed': completedList,
      };
    } catch (e) {
      print('Simkl fetchWatchlistCatalogs error: $e');
      return _decodeWatchlistsFromCache(prefs);
    }
  }

  static void _categorizeSimklItems(
    List<dynamic> items,
    List<MetaPreview> watching,
    List<MetaPreview> planToWatch,
    List<MetaPreview> completed,
  ) {
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final parsed = _parseSimklItem(raw);
      if (parsed == null) continue;

      final status = (raw['status'] as String? ?? '').toLowerCase();

      // Deduplicate
      watching.removeWhere((e) => e.id == parsed.id);
      planToWatch.removeWhere((e) => e.id == parsed.id);
      completed.removeWhere((e) => e.id == parsed.id);

      if (status == 'watching') {
        watching.insert(0, parsed);
      } else if (status == 'plantowatch' || status == 'plan_to_watch' || status == 'hold') {
        planToWatch.insert(0, parsed);
      } else if (status == 'completed') {
        completed.insert(0, parsed);
      }
    }
  }

  static Map<String, List<MetaPreview>> _decodeWatchlistsFromCache(SharedPreferences prefs) {
    List<MetaPreview> decodeKey(String key) {
      final raw = prefs.getString(key);
      if (raw == null) return [];
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded.map((e) => MetaPreview.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }

    return {
      'watching': decodeKey('simkl_cache_watching'),
      'plantowatch': decodeKey('simkl_cache_plantowatch'),
      'completed': decodeKey('simkl_cache_completed'),
    };
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_tv_media3/flutter_tv_media3.dart';
import 'settings.dart';

class SkipSegmentClient {
  static Future<List<MediaSegment>?> fetchSkipSegments(String videoId) async {
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
    final secondaryProvider = primaryProvider == 'introdb.app'
        ? 'theintrodb.org'
        : 'introdb.app';

    print(
      '[INTROSKIP] Fetching skip segments for ID: $videoId (imdb: $imdbId, season: $season, ep: $episode) using $primaryProvider',
    );

    var segments = await _tryFetchSkipSegments(
      primaryProvider,
      imdbId,
      season,
      episode,
    );

    if (segments == null) {
      print(
        '[INTROSKIP] $primaryProvider failed or returned error. Falling back to $secondaryProvider',
      );
      segments = await _tryFetchSkipSegments(
        secondaryProvider,
        imdbId,
        season,
        episode,
      );
    }

    if (segments != null) {
      print('[INTROSKIP] segments retrieved ( found):');
      for (var seg in segments) {
        print(
          '  -> [] start: s, end: s',
        );
      }
      return segments;
    }

    print('[INTROSKIP] segments retrieved (0 segments found)');
    return null;
  }

  static Future<List<MediaSegment>?> _tryFetchSkipSegments(
    String provider,
    String imdbId,
    String? season,
    String? episode,
  ) async {
    try {
      if (provider == 'introdb.app' || provider == 'theintrodb.org') {
        String url = 'https://api.introdb.app/segments?imdb_id=$imdbId';
        if (season != null && episode != null) {
          url += '&season=$season&episode=$episode';
        }
        print('[INTROSKIP] Request URL ($provider): $url');
        final res = await http.get(Uri.parse(url));
        print(
          '[INTROSKIP] Response HTTP status ($provider): ',
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final segments = <MediaSegment>[];
          if (data['intro'] != null) {
            for (var i in data['intro'])
              segments.add(MediaSegment.fromJson(i, 'intro'));
          }
          if (data['recap'] != null) {
            for (var r in data['recap'])
              segments.add(MediaSegment.fromJson(r, 'recap'));
          }
          if (data['credits'] != null) {
            for (var c in data['credits'])
              segments.add(MediaSegment.fromJson(c, 'credits'));
          }
          if (data['preview'] != null) {
            for (var p in data['preview'])
              segments.add(MediaSegment.fromJson(p, 'preview'));
          }
          return segments;
        }
      }
    } catch (e) {
      print('[INTROSKIP] Error fetching from $provider: $e');
    }
    return null;
  }
}

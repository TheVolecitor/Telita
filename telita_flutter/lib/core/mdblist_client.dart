import 'dart:convert';
import 'package:http/http.dart' as http;

class MdbRatingItem {
  final String source;
  final dynamic value;
  final int? score;

  MdbRatingItem({
    required this.source,
    this.value,
    this.score,
  });

  factory MdbRatingItem.fromJson(Map<String, dynamic> json) {
    return MdbRatingItem(
      source: (json['source'] ?? '').toString().toLowerCase(),
      value: json['value'],
      score: json['score'] is int ? json['score'] : int.tryParse(json['score']?.toString() ?? ''),
    );
  }
}

class MdbListRatings {
  final int? overallScore;
  final List<MdbRatingItem> ratings;

  MdbListRatings({
    this.overallScore,
    required this.ratings,
  });

  factory MdbListRatings.fromJson(Map<String, dynamic> json) {
    final list = <MdbRatingItem>[];
    if (json['ratings'] != null && json['ratings'] is List) {
      for (var r in json['ratings']) {
        if (r is Map<String, dynamic>) {
          list.add(MdbRatingItem.fromJson(r));
        }
      }
    }
    final score = json['score'] is int 
        ? json['score'] 
        : int.tryParse(json['score']?.toString() ?? '');
    return MdbListRatings(
      overallScore: score,
      ratings: list,
    );
  }

  MdbRatingItem? getRating(String source) {
    try {
      return ratings.firstWhere((r) => r.source == source.toLowerCase());
    } catch (_) {
      return null;
    }
  }
}

class MdbListClient {
  static Future<MdbListRatings?> fetchRatings(String imdbId, String apiKey) async {
    if (apiKey.isEmpty || imdbId.isEmpty) return null;
    try {
      final cleanId = imdbId.split(':')[0]; // strip season/ep
      final url = 'https://mdblist.com/api/?apikey=$apiKey&i=$cleanId';
      print('[MDBLIST] Requesting ratings from: $url');
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      print('[MDBLIST] Response HTTP status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final ratings = MdbListRatings.fromJson(data);
          print('[MDBLIST] Successfully fetched ratings: score=${ratings.overallScore}, sources=${ratings.ratings.map((r) => r.source).join(', ')}');
          return ratings;
        }
      }
    } catch (e) {
      print('[MDBLIST] Error fetching ratings: $e');
    }
    return null;
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'auth.dart';

List<dynamic> _decodeJsonList(String body) => jsonDecode(body) as List<dynamic>;

class WatchEntry {
  final String id;
  final String type; // "movie" | "series"
  final String name;
  final String? poster;
  final String streamUrl;
  final int timestamp;
  final int duration;
  final int updatedAt;

  WatchEntry({
    required this.id,
    required this.type,
    required this.name,
    this.poster,
    required this.streamUrl,
    required this.timestamp,
    required this.duration,
    required this.updatedAt,
  });

  factory WatchEntry.fromJson(Map<String, dynamic> json) {
    return WatchEntry(
      id: json['id'] ?? json['content_id'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      poster: json['poster'],
      streamUrl: json['streamUrl'] ?? json['stream_url'] ?? '',
      timestamp: (json['timestamp'] ?? 0).toInt(),
      duration: (json['duration'] ?? 0).toInt(),
      updatedAt: json['updatedAt'] ?? json['updated_at'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        if (poster != null) 'poster': poster,
        'streamUrl': streamUrl,
        'timestamp': timestamp,
        'duration': duration,
        'updatedAt': updatedAt,
      };

  Map<String, dynamic> toServerJson() => {
        'id': id,
        'type': type,
        'name': name,
        if (poster != null) 'poster': poster,
        'streamUrl': streamUrl,
        'timestamp': timestamp,
        'duration': duration,
        'updatedAt': updatedAt,
      };
}

class WatchHistory extends ValueNotifier<List<WatchEntry>> {
  static const String _storageKey = "telita_watch_history";
  static const int _maxEntries = 50;

  static final WatchHistory instance = WatchHistory._internal();
  WatchHistory._internal() : super([]);

  String? _profileId;
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final List<dynamic> decoded = await compute(_decodeJsonList, raw);
        final list = decoded.map((e) => WatchEntry.fromJson(e)).toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        value = list;
      } catch (e) {
        print("Error reading local watch history: $e");
      }
    }
  }

  Future<void> setProfile(String? profileId, String? token) async {
    _profileId = profileId;
    _token = token;
    
    if (_profileId == null || _token == null) {
      // Re-load local storage if guest
      await init();
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$defaultApiUrl/api/sync/history?profile_id=$_profileId'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (res.statusCode == 200) {
        final List<dynamic> decoded = await compute(_decodeJsonList, res.body);
        final list = decoded.map((e) => WatchEntry.fromJson(e)).toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        value = list;
        // Optionally save to local for offline caching
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, jsonEncode(list.map((e) => e.toJson()).toList()));
      }
    } catch (e) {
      print("Error fetching server watch history: $e");
      await init(); // fallback to local
    }
  }

  Future<void> _persist(List<WatchEntry> list, {WatchEntry? newEntry, String? deletedId}) async {
    // 1. Save local
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
    value = list;

    // 2. Sync to server if profile is logged in
    if (_profileId != null && _token != null) {
      try {
        if (deletedId != null) {
           await http.delete(
            Uri.parse('$defaultApiUrl/api/sync/history/${Uri.encodeComponent(deletedId)}?profile_id=$_profileId'),
            headers: {'Authorization': 'Bearer $_token'},
          );
        } else if (newEntry != null) {
          await http.post(
            Uri.parse('$defaultApiUrl/api/sync/history?profile_id=$_profileId'),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'entries': [newEntry.toServerJson()]
            }),
          );
        }
      } catch (e) {
        print("Error syncing watch history to server: $e");
      }
    }
  }

  Future<void> save(WatchEntry entry) async {
    final list = List<WatchEntry>.from(value);
    final idx = list.indexWhere((e) => e.id == entry.id);
    
    WatchEntry entryToSave = entry;

    if (idx >= 0) {
      if (list[idx].updatedAt >= entry.updatedAt) {
        entryToSave = WatchEntry(
          id: entry.id,
          type: entry.type,
          name: entry.name,
          poster: entry.poster,
          streamUrl: entry.streamUrl,
          timestamp: entry.timestamp,
          duration: entry.duration,
          updatedAt: list[idx].updatedAt + 1000,
        );
      }
      list[idx] = entryToSave;
    } else {
      list.insert(0, entryToSave);
    }
    
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (list.length > _maxEntries) {
      list.removeRange(_maxEntries, list.length);
    }
    await _persist(list, newEntry: entryToSave);
  }

  WatchEntry? get(String id) {
    final idx = value.indexWhere((e) => e.id == id);
    return idx >= 0 ? value[idx] : null;
  }

  Future<void> remove(String id) async {
    final list = value.where((e) => e.id != id).toList();
    await _persist(list, deletedId: id);
  }

  Future<void> clear() async {
    await _persist([]);
    // Clearing server side entirely not easily supported via single API call in this DB schema without looping,
    // so we just clear local for now or we could add a clear all endpoint later.
  }

  double getProgress(WatchEntry entry) {
    if (entry.duration == 0) return 0.0;
    return (entry.timestamp / entry.duration).clamp(0.0, 1.0);
  }
}

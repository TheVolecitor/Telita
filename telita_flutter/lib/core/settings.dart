import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'auth.dart';

class AppSettings {
  bool subtitleEnabled;
  String subtitleLanguage;
  int subtitleFontSize;
  int subtitlePosition;
  String subtitleStyle;
  String subtitleColor;
  int subtitleBgOpacity;
  String hardwareDecoding;
  int defaultVolume;
  bool rememberVolume;
  bool resumePrompt;
  String appTheme;
  bool introSkipEnabled;
  String introSkipProvider;
  bool mdbListEnabled;
  String mdbListApiKey;
  bool mdbListShowImdb;
  bool mdbListShowTomatoes;
  bool mdbListShowMetacritic;
  bool mdbListShowLetterboxd;
  bool mdbListShowTrakt;
  bool mdbListShowScore;
  bool simklEnabled;
  String simklClientId;
  String simklClientSecret;
  String simklAccessToken;
  String simklUsername;
  String customPrimaryColor;
  String customSecondaryColor;
  String catalogConfigJson;
  double discoverScale;

  AppSettings({
    this.subtitleEnabled = true,
    this.subtitleLanguage = 'eng',
    this.subtitleFontSize = 32,
    this.subtitlePosition = 85,
    this.subtitleStyle = 'default',
    this.subtitleColor = '#ffffff',
    this.subtitleBgOpacity = 0,
    this.hardwareDecoding = 'auto',
    this.defaultVolume = 100,
    this.rememberVolume = true,
    this.resumePrompt = true,
    this.appTheme = 'default',
    this.introSkipEnabled = true,
    this.introSkipProvider = 'introdb.app',
    this.mdbListEnabled = true,
    this.mdbListApiKey = '',
    this.mdbListShowImdb = true,
    this.mdbListShowTomatoes = true,
    this.mdbListShowMetacritic = true,
    this.mdbListShowLetterboxd = true,
    this.mdbListShowTrakt = true,
    this.mdbListShowScore = true,
    this.simklEnabled = true,
    this.simklClientId = '',
    this.simklClientSecret = '',
    this.simklAccessToken = '',
    this.simklUsername = '',
    this.customPrimaryColor = '#6C63FF',
    this.customSecondaryColor = '#8A84FF',
    this.catalogConfigJson = '{}',
    this.discoverScale = 1.0,
  });

  factory AppSettings.fromPrefs(SharedPreferences prefs) {
    return AppSettings(
      subtitleEnabled: prefs.getBool('subtitleEnabled') ?? true,
      subtitleLanguage: prefs.getString('subtitleLanguage') ?? 'eng',
      subtitleFontSize: prefs.getInt('subtitleFontSize') ?? 32,
      subtitlePosition: prefs.getInt('subtitlePosition') ?? 85,
      subtitleStyle: prefs.getString('subtitleStyle') ?? 'default',
      subtitleColor: prefs.getString('subtitleColor') ?? '#ffffff',
      subtitleBgOpacity: prefs.getInt('subtitleBgOpacity') ?? 0,
      hardwareDecoding: prefs.getString('hardwareDecoding') ?? 'auto',
      defaultVolume: prefs.getInt('defaultVolume') ?? 100,
      rememberVolume: prefs.getBool('rememberVolume') ?? true,
      resumePrompt: prefs.getBool('resumePrompt') ?? true,
      appTheme: prefs.getString('appTheme') ?? 'default',
      introSkipEnabled: prefs.getBool('introSkipEnabled') ?? true,
      introSkipProvider: prefs.getString('introSkipProvider') ?? 'introdb.app',
      mdbListEnabled: prefs.getBool('mdbListEnabled') ?? true,
      mdbListApiKey: prefs.getString('mdbListApiKey') ?? '',
      mdbListShowImdb: prefs.getBool('mdbListShowImdb') ?? true,
      mdbListShowTomatoes: prefs.getBool('mdbListShowTomatoes') ?? true,
      mdbListShowMetacritic: prefs.getBool('mdbListShowMetacritic') ?? true,
      mdbListShowLetterboxd: prefs.getBool('mdbListShowLetterboxd') ?? true,
      mdbListShowTrakt: prefs.getBool('mdbListShowTrakt') ?? true,
      mdbListShowScore: prefs.getBool('mdbListShowScore') ?? true,
      simklEnabled: prefs.getBool('simklEnabled') ?? true,
      simklClientId: prefs.getString('simklClientId') ?? '',
      simklClientSecret: prefs.getString('simklClientSecret') ?? '',
      simklAccessToken: prefs.getString('simklAccessToken') ?? '',
      simklUsername: prefs.getString('simklUsername') ?? '',
      customPrimaryColor: prefs.getString('customPrimaryColor') ?? '#6C63FF',
      customSecondaryColor: prefs.getString('customSecondaryColor') ?? '#8A84FF',
      catalogConfigJson: prefs.getString('catalogConfigJson') ?? '{}',
      discoverScale: prefs.getDouble('discoverScale') ?? 1.0,
    );
  }

  void save(SharedPreferences prefs) {
    prefs.setBool('subtitleEnabled', subtitleEnabled);
    prefs.setString('subtitleLanguage', subtitleLanguage);
    prefs.setInt('subtitleFontSize', subtitleFontSize);
    prefs.setInt('subtitlePosition', subtitlePosition);
    prefs.setString('subtitleStyle', subtitleStyle);
    prefs.setString('subtitleColor', subtitleColor);
    prefs.setInt('subtitleBgOpacity', subtitleBgOpacity);
    prefs.setString('hardwareDecoding', hardwareDecoding);
    prefs.setInt('defaultVolume', defaultVolume);
    prefs.setBool('rememberVolume', rememberVolume);
    prefs.setBool('resumePrompt', resumePrompt);
    prefs.setString('appTheme', appTheme);
    prefs.setBool('introSkipEnabled', introSkipEnabled);
    prefs.setString('introSkipProvider', introSkipProvider);
    prefs.setBool('mdbListEnabled', mdbListEnabled);
    prefs.setString('mdbListApiKey', mdbListApiKey);
    prefs.setBool('mdbListShowImdb', mdbListShowImdb);
    prefs.setBool('mdbListShowTomatoes', mdbListShowTomatoes);
    prefs.setBool('mdbListShowMetacritic', mdbListShowMetacritic);
    prefs.setBool('mdbListShowLetterboxd', mdbListShowLetterboxd);
    prefs.setBool('mdbListShowTrakt', mdbListShowTrakt);
    prefs.setBool('mdbListShowScore', mdbListShowScore);
    prefs.setBool('simklEnabled', simklEnabled);
    prefs.setString('simklClientId', simklClientId);
    prefs.setString('simklClientSecret', simklClientSecret);
    prefs.setString('simklAccessToken', simklAccessToken);
    prefs.setString('simklUsername', simklUsername);
    prefs.setString('customPrimaryColor', customPrimaryColor);
    prefs.setString('customSecondaryColor', customSecondaryColor);
    prefs.setString('catalogConfigJson', catalogConfigJson);
    prefs.setDouble('discoverScale', discoverScale);
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      subtitleEnabled: json['subtitleEnabled'] ?? true,
      subtitleLanguage: json['subtitleLanguage'] ?? 'eng',
      subtitleFontSize: json['subtitleFontSize'] ?? 32,
      subtitlePosition: json['subtitlePosition'] ?? 85,
      subtitleStyle: json['subtitleStyle'] ?? 'default',
      subtitleColor: json['subtitleColor'] ?? '#ffffff',
      subtitleBgOpacity: json['subtitleBgOpacity'] ?? 0,
      hardwareDecoding: json['hardwareDecoding'] ?? 'auto',
      defaultVolume: json['defaultVolume'] ?? 100,
      rememberVolume: json['rememberVolume'] ?? true,
      resumePrompt: json['resumePrompt'] ?? true,
      appTheme: json['appTheme'] ?? 'default',
      introSkipEnabled: json['introSkipEnabled'] ?? true,
      introSkipProvider: json['introSkipProvider'] ?? 'introdb.app',
      mdbListEnabled: json['mdbListEnabled'] ?? true,
      mdbListApiKey: json['mdbListApiKey'] ?? '',
      mdbListShowImdb: json['mdbListShowImdb'] ?? true,
      mdbListShowTomatoes: json['mdbListShowTomatoes'] ?? true,
      mdbListShowMetacritic: json['mdbListShowMetacritic'] ?? true,
      mdbListShowLetterboxd: json['mdbListShowLetterboxd'] ?? true,
      mdbListShowTrakt: json['mdbListShowTrakt'] ?? true,
      mdbListShowScore: json['mdbListShowScore'] ?? true,
      simklEnabled: json['simklEnabled'] ?? true,
      simklClientId: json['simklClientId'] ?? '',
      simklClientSecret: json['simklClientSecret'] ?? '',
      simklAccessToken: json['simklAccessToken'] ?? '',
      simklUsername: json['simklUsername'] ?? '',
      customPrimaryColor: json['customPrimaryColor'] ?? '#6C63FF',
      customSecondaryColor: json['customSecondaryColor'] ?? '#8A84FF',
      catalogConfigJson: json['catalogConfigJson'] ?? '{}',
      discoverScale: (json['discoverScale'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'subtitleEnabled': subtitleEnabled,
        'subtitleLanguage': subtitleLanguage,
        'subtitleFontSize': subtitleFontSize,
        'subtitlePosition': subtitlePosition,
        'subtitleStyle': subtitleStyle,
        'subtitleColor': subtitleColor,
        'subtitleBgOpacity': subtitleBgOpacity,
        'hardwareDecoding': hardwareDecoding,
        'defaultVolume': defaultVolume,
        'rememberVolume': rememberVolume,
        'resumePrompt': resumePrompt,
        'appTheme': appTheme,
        'introSkipEnabled': introSkipEnabled,
        'introSkipProvider': introSkipProvider,
        'mdbListEnabled': mdbListEnabled,
        'mdbListApiKey': mdbListApiKey,
        'mdbListShowImdb': mdbListShowImdb,
        'mdbListShowTomatoes': mdbListShowTomatoes,
        'mdbListShowMetacritic': mdbListShowMetacritic,
        'mdbListShowLetterboxd': mdbListShowLetterboxd,
        'mdbListShowTrakt': mdbListShowTrakt,
        'mdbListShowScore': mdbListShowScore,
        'simklEnabled': simklEnabled,
        'simklClientId': simklClientId,
        'simklClientSecret': simklClientSecret,
        'simklAccessToken': simklAccessToken,
        'simklUsername': simklUsername,
        'customPrimaryColor': customPrimaryColor,
        'customSecondaryColor': customSecondaryColor,
        'catalogConfigJson': catalogConfigJson,
        'discoverScale': discoverScale,
      };
}

class SettingsService extends ValueNotifier<AppSettings> {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal() : super(AppSettings());

  String? _profileId;
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    value = AppSettings.fromPrefs(prefs);
  }

  Future<void> setProfile(String? profileId, String? token) async {
    _profileId = profileId;
    _token = token;

    if (_profileId == null || _token == null) {
      // Re-load local preferences if guest/logged out
      await init();
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$defaultApiUrl/api/sync/settings?profile_id=$_profileId'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final serverSettings = AppSettings.fromJson(data);
          final prefs = await SharedPreferences.getInstance();
          serverSettings.save(prefs); // save to local immediately
          value = serverSettings;
          notifyListeners();
        } else {
          // No settings on server, so push current local settings
          await _syncToServer(value);
        }
      }
    } catch (e) {
      print("Error fetching server settings: $e");
      await init();
    }
  }

  Future<void> _syncToServer(AppSettings settings) async {
    if (_profileId == null || _token == null) return;
    try {
      await http.post(
        Uri.parse('$defaultApiUrl/api/sync/settings?profile_id=$_profileId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(settings.toJson()),
      );
    } catch (e) {
      print("Error syncing settings to server: $e");
    }
  }

  Future<void> set<K>(String key, K val) async {
    final prefs = await SharedPreferences.getInstance();
    final current = value;
    
    if (key == 'subtitleEnabled' && val is bool) current.subtitleEnabled = val;
    if (key == 'subtitleLanguage' && val is String) current.subtitleLanguage = val;
    if (key == 'subtitleFontSize' && val is int) current.subtitleFontSize = val;
    if (key == 'subtitlePosition' && val is int) current.subtitlePosition = val;
    if (key == 'subtitleStyle' && val is String) current.subtitleStyle = val;
    if (key == 'subtitleColor' && val is String) current.subtitleColor = val;
    if (key == 'subtitleBgOpacity' && val is int) current.subtitleBgOpacity = val;
    if (key == 'hardwareDecoding' && val is String) current.hardwareDecoding = val;
    if (key == 'defaultVolume' && val is int) current.defaultVolume = val;
    if (key == 'rememberVolume' && val is bool) current.rememberVolume = val;
    if (key == 'resumePrompt' && val is bool) current.resumePrompt = val;
    if (key == 'appTheme' && val is String) current.appTheme = val;
    if (key == 'introSkipEnabled' && val is bool) current.introSkipEnabled = val;
    if (key == 'introSkipProvider' && val is String) current.introSkipProvider = val;
    if (key == 'mdbListEnabled' && val is bool) current.mdbListEnabled = val;
    if (key == 'mdbListApiKey' && val is String) current.mdbListApiKey = val;
    if (key == 'mdbListShowImdb' && val is bool) current.mdbListShowImdb = val;
    if (key == 'mdbListShowTomatoes' && val is bool) current.mdbListShowTomatoes = val;
    if (key == 'mdbListShowMetacritic' && val is bool) current.mdbListShowMetacritic = val;
    if (key == 'mdbListShowLetterboxd' && val is bool) current.mdbListShowLetterboxd = val;
    if (key == 'mdbListShowTrakt' && val is bool) current.mdbListShowTrakt = val;
    if (key == 'mdbListShowScore' && val is bool) current.mdbListShowScore = val;
    if (key == 'simklEnabled' && val is bool) current.simklEnabled = val;
    if (key == 'simklClientId' && val is String) current.simklClientId = val;
    if (key == 'simklClientSecret' && val is String) current.simklClientSecret = val;
    if (key == 'simklAccessToken' && val is String) current.simklAccessToken = val;
    if (key == 'simklUsername' && val is String) current.simklUsername = val;
    if (key == 'customPrimaryColor' && val is String) current.customPrimaryColor = val;
    if (key == 'customSecondaryColor' && val is String) current.customSecondaryColor = val;
    if (key == 'catalogConfigJson' && val is String) current.catalogConfigJson = val;
    if (key == 'discoverScale' && val is double) current.discoverScale = val;

    current.save(prefs);
    value = current;
    notifyListeners();

    _syncToServer(current);
  }
}

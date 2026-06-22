import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String subtitleFontFamily;
  String subtitleFontWeight;
  String defaultPlayer;

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
    this.subtitleFontFamily = 'Arial',
    this.subtitleFontWeight = 'normal',
    this.defaultPlayer = 'native',
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
      subtitleFontFamily: prefs.getString('subtitleFontFamily') ?? 'Arial',
      subtitleFontWeight: prefs.getString('subtitleFontWeight') ?? 'normal',
      defaultPlayer: prefs.getString('defaultPlayer') ?? 'native',
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
    prefs.setString('subtitleFontFamily', subtitleFontFamily);
    prefs.setString('subtitleFontWeight', subtitleFontWeight);
    prefs.setString('defaultPlayer', defaultPlayer);
  }
}

class SettingsService extends ValueNotifier<AppSettings> {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal() : super(AppSettings());

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    value = AppSettings.fromPrefs(prefs);
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
    if (key == 'subtitleFontFamily' && val is String) current.subtitleFontFamily = val;
    if (key == 'subtitleFontWeight' && val is String) current.subtitleFontWeight = val;
    if (key == 'defaultPlayer' && val is String) current.defaultPlayer = val;

    current.save(prefs);
    value = current;
    notifyListeners();
  }
}

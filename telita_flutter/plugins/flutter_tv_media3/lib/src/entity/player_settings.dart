import 'package:flutter_tv_media3/src/localization/overlay_localizations.dart';
import 'dart:ui';

/// Represents player settings that affect track selection and video quality.
///
/// This class contains parameters that the native player uses to
/// automatically select the best audio and subtitle tracks according to
/// user preferences, and to limit the video quality.
///
/// A `PlayerSettings` object is passed to the player before it is created.
/// The application can save these settings (e.g., in SharedPreferences)
/// to restore the user's choice on subsequent launches. If the settings
/// are not provided, the player uses default values.
class PlayerSettings {
  const PlayerSettings({
    this.videoQuality = VideoQuality.max,
    this.preferredAudioLanguages,
    this.preferredTextLanguages,
    this.forcedAutoEnable = true,
    this.deviceLocale,
    this.isAfrEnabled = false,
    this.forceHighestBitrate = true,
    this.stuckBufferingDetectionTimeoutMs = 240000,
    this.stuckPlayingDetectionTimeoutMs = 120000,
    this.stuckPlayingNotEndingTimeoutMs = 180000,
    this.stuckSuppressedDetectionTimeoutMs = 480000,
    this.paginationThreshold = 5,
    this.paginationEnable = false,
    this.screenshotsEnable = false,
  });

  /// The desired video quality. The player will try to select a stream
  /// that does not exceed the width and height limits specified here.
  final VideoQuality videoQuality;

  /// A list of preferred languages for audio tracks, ordered by priority.
  /// Uses ISO 639-1 language codes (e.g., "de", "en").
  final List<String>? preferredAudioLanguages;

  /// A list of preferred languages for subtitles, ordered by priority.
  /// Uses ISO 639-1 language codes (e.g., "de", "en").
  final List<String>? preferredTextLanguages;

  /// A flag indicating whether to automatically enable subtitles
  /// if they are marked as "forced".
  final bool forcedAutoEnable;

  /// The device's locale. Used as an additional criterion for selecting
  /// language tracks if the `preferred...Languages` lists are not provided.
  final Locale? deviceLocale;

  /// A flag that enables or disables the Auto Frame Rate (AFR) feature.
  /// When enabled, the player will attempt to match the display's refresh
  /// rate to the video's frame rate for smoother playback.
  /// Defaults to `false`.
  final bool isAfrEnabled;

  /// Whether to force the highest supported bitrate within the
  /// selected quality constraints.
  /// Defaults to `true`.
  final bool forceHighestBitrate;

  /// The timeout in milliseconds for detecting stuck buffering.
  /// Defaults to 240,000 (4 minutes).
  final int stuckBufferingDetectionTimeoutMs;

  /// The timeout in milliseconds for detecting stuck playing.
  /// Defaults to 120,000 (2 minutes).
  final int stuckPlayingDetectionTimeoutMs;

  /// The timeout in milliseconds for detecting stuck playing not ending.
  /// Defaults to 180,000 (3 minutes).
  final int stuckPlayingNotEndingTimeoutMs;

  /// The timeout in milliseconds for detecting stuck suppressed.
  /// Defaults to 480,000 (8 minutes).
  final int stuckSuppressedDetectionTimeoutMs;

  /// The number of items from the end of the playlist at which
  /// pagination should be triggered.
  final int paginationThreshold;

  /// Whether pagination is enabled.
  final bool paginationEnable;

  /// Whether screenshot functionality is enabled.
  final bool screenshotsEnable;

  Map<String, dynamic> toMap() {
    return {
      'videoQuality': videoQuality.index,
      'width': videoQuality.width,
      'height': videoQuality.height,
      'preferredAudioLanguages': preferredAudioLanguages,
      'preferredTextLanguages': preferredTextLanguages,
      'forcedAutoEnable': forcedAutoEnable,
      'deviceLocale': _localeToString(deviceLocale),
      'isAfrEnabled': isAfrEnabled,
      'forceHighestBitrate': forceHighestBitrate,
      'stuckBufferingDetectionTimeoutMs': stuckBufferingDetectionTimeoutMs,
      'stuckPlayingDetectionTimeoutMs': stuckPlayingDetectionTimeoutMs,
      'stuckPlayingNotEndingTimeoutMs': stuckPlayingNotEndingTimeoutMs,
      'stuckSuppressedDetectionTimeoutMs': stuckSuppressedDetectionTimeoutMs,
      'paginationThreshold': paginationThreshold,
      'paginationEnable': paginationEnable,
      'screenshotsEnable': screenshotsEnable,
    };
  }

  factory PlayerSettings.fromMap(Map<dynamic, dynamic> map) {
    return PlayerSettings(
      videoQuality: VideoQuality.fromIndex(map['videoQuality'] as int?),
      preferredAudioLanguages:
          (map['preferredAudioLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      preferredTextLanguages:
          (map['preferredTextLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      forcedAutoEnable: map['forcedAutoEnable'] as bool? ?? true,
      deviceLocale: _localeFromString(map['deviceLocale']),
      isAfrEnabled: map['isAfrEnabled'] as bool? ?? false,
      forceHighestBitrate: map['forceHighestBitrate'] as bool? ?? true,
      stuckBufferingDetectionTimeoutMs:
          map['stuckBufferingDetectionTimeoutMs'] as int? ?? 240000,
      stuckPlayingDetectionTimeoutMs:
          map['stuckPlayingDetectionTimeoutMs'] as int? ?? 120000,
      stuckPlayingNotEndingTimeoutMs:
          map['stuckPlayingNotEndingTimeoutMs'] as int? ?? 180000,
      stuckSuppressedDetectionTimeoutMs:
          map['stuckSuppressedDetectionTimeoutMs'] as int? ?? 480000,
      paginationThreshold: map['paginationThreshold'] as int? ?? 5,
      paginationEnable: map['paginationEnable'] as bool? ?? false,
      screenshotsEnable: map['screenshotsEnable'] as bool? ?? false,
    );
  }

  PlayerSettings copyWith({
    VideoQuality? videoQuality,
    List<String>? preferredAudioLanguages,
    List<String>? preferredTextLanguages,
    bool? forcedAutoEnable,
    bool? isAfrEnabled,
    bool? forceHighestBitrate,
    int? stuckBufferingDetectionTimeoutMs,
    int? stuckPlayingDetectionTimeoutMs,
    int? stuckPlayingNotEndingTimeoutMs,
    int? stuckSuppressedDetectionTimeoutMs,
    int? paginationThreshold,
    bool? paginationEnable,
    bool? screenshotsEnable,
    Locale? deviceLocale,
  }) {
    return PlayerSettings(
      videoQuality: videoQuality ?? this.videoQuality,
      preferredAudioLanguages:
          preferredAudioLanguages ?? this.preferredAudioLanguages,
      preferredTextLanguages:
          preferredTextLanguages ?? this.preferredTextLanguages,
      forcedAutoEnable: forcedAutoEnable ?? this.forcedAutoEnable,
      isAfrEnabled: isAfrEnabled ?? this.isAfrEnabled,
      forceHighestBitrate: forceHighestBitrate ?? this.forceHighestBitrate,
      stuckBufferingDetectionTimeoutMs:
          stuckBufferingDetectionTimeoutMs ??
          this.stuckBufferingDetectionTimeoutMs,
      stuckPlayingDetectionTimeoutMs:
          stuckPlayingDetectionTimeoutMs ?? this.stuckPlayingDetectionTimeoutMs,
      stuckPlayingNotEndingTimeoutMs:
          stuckPlayingNotEndingTimeoutMs ?? this.stuckPlayingNotEndingTimeoutMs,
      stuckSuppressedDetectionTimeoutMs:
          stuckSuppressedDetectionTimeoutMs ??
          this.stuckSuppressedDetectionTimeoutMs,
      paginationThreshold: paginationThreshold ?? this.paginationThreshold,
      paginationEnable: paginationEnable ?? this.paginationEnable,
      screenshotsEnable: screenshotsEnable ?? this.screenshotsEnable,
      deviceLocale: deviceLocale ?? this.deviceLocale,
    );
  }

  @override
  String toString() {
    return '''PlayerSettings{
      videoQuality: $videoQuality, 
      preferredAudioLanguages: $preferredAudioLanguages, 
      preferredTextLanguages: $preferredTextLanguages, 
      forcedAutoEnable: $forcedAutoEnable,
      isAfrEnabled: $isAfrEnabled,
      forceHighestBitrate: $forceHighestBitrate,
      stuckBufferingDetectionTimeoutMs: $stuckBufferingDetectionTimeoutMs,
      stuckPlayingDetectionTimeoutMs: $stuckPlayingDetectionTimeoutMs,
      stuckPlayingNotEndingTimeoutMs: $stuckPlayingNotEndingTimeoutMs,
      stuckSuppressedDetectionTimeoutMs: $stuckSuppressedDetectionTimeoutMs,
      paginationThreshold: $paginationThreshold,
      paginationEnable: $paginationEnable,
      screenshotsEnable: $screenshotsEnable
    }''';
  }

  String? _localeToString(Locale? locale) {
    if (locale == null) return null;
    return locale.countryCode != null
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
  }

  static Locale? _localeFromString(String? localeString) {
    if (localeString == null || localeString.isEmpty) return null;
    final parts = localeString.split('_');
    return parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }
}

/// Defines video quality levels to limit stream selection.
///
/// Each level (except `max` and `min`) has associated
/// width and height values that are used by the player for filtering.
enum VideoQuality {
  /// Maximum available quality (no restrictions).
  max("videoQualityMax", 0, 0),

  /// High quality (up to ~1080p).
  high("videoQualityHigh", 1999, 1100),

  /// Medium quality (up to ~720p).
  medium("videoQualityMedium", 1400, 800),

  /// Low quality (up to ~540p).
  low("videoQualityLow", 900, 550),

  /// Minimum available quality.
  min("videoQualityMin", 0, 0);

  const VideoQuality(this.key, this.width, this.height);

  /// The key for localizing the quality name.
  final String key;

  /// The localized quality name for display in the UI.
  String get title => OverlayLocalizations.get(key);

  /// The maximum width for this quality level.
  final int? width;

  /// The maximum height for this quality level.
  final int? height;

  static VideoQuality fromIndex(int? index) =>
      index != null ? values[index] : values[0];

  static VideoQuality changeValue({
    required int index,
    required int direction,
  }) {
    final length = VideoQuality.values.length;
    final newIndex = (index + direction + length) % length;
    return VideoQuality.values[newIndex];
  }
}

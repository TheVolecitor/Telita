import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'default_locale_strings.dart';

/// A static class that manages localization for the UI overlay.
///
/// This class implements a custom localization strategy where all strings
/// are provided by the main application via a `MethodChannel`, ensuring a
/// single source of truth for translations.
///
/// It also handles locale-specific date and time formatting.
class OverlayLocalizations {
  // A map to hold the localized strings.
  static Map<String, String> _strings = DefaultLocaleStrings.values;

  // The current locale, defaulting to 'en_US'.
  static Locale _locale = const Locale('en', 'US');

  /// Initializes the localization service.
  ///

  /// This should be called once at the start of the overlay to set up
  /// default date formatting for the initial locale.
  static void init() {
    initializeDateFormatting(_locale.toLanguageTag());
  }

  /// Updates the current locale and loads the necessary formatting data.
  static void updateLocale(Locale newLocale) {
    _locale = newLocale;
    initializeDateFormatting(_locale.toLanguageTag());
  }

  /// Loads and merges new localization strings.
  ///
  /// This method is called once when localization data is received
  /// from the native side. New strings from [newStrings] will overwrite
  /// existing default values if the keys match.
  static void load(Map<String, String> newStrings) {
    _strings = {..._strings, ...newStrings};
  }

  /// Gets the localized string for the given [key].
  ///
  /// If the string for the given key is not found, the method returns the [key]
  /// itself as a fallback. This helps to easily identify missing
  /// translations during development.
  static String get(String key) {
    return _strings[key] ?? key;
  }

  /// Formats the time part of a [DateTime] object according to the current locale.
  static String timeFormat({required DateTime date}) {
    return DateFormat.Hm(_locale.toString()).format(date);
  }

  /// Formats the date part of a [DateTime] object according to the current locale.
  static String dateFormat({required DateTime date}) {
    return DateFormat.yMd(_locale.toString()).format(date);
  }

  /// Formats the day of the week of a [DateTime] object according to the current locale.
  static String dayFormat({required DateTime date}) {
    return DateFormat.E(_locale.toString()).format(date);
  }

  /// Formats a time range. If the start and end times are on the same day,
  /// it only shows the time. Otherwise, it includes the date.
  static String formatShortTimeRange(DateTime startTime, DateTime endTime) {
    final timeFormat = DateFormat.Hm(_locale.toString());
    if (startTime.year == endTime.year &&
        startTime.month == endTime.month &&
        startTime.day == endTime.day) {
      return '${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}';
    } else {
      final dateTimeFormat = DateFormat.Md(_locale.toString()).add_Hm();
      return '${dateTimeFormat.format(startTime)} - ${dateTimeFormat.format(endTime)}';
    }
  }
}

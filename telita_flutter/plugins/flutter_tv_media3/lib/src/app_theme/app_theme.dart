import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  static final borderRadius = BorderRadius.circular(8);
  static const radius = Radius.circular(8);
  static const int epgPageCount = 3;
  static const double customListItemExtent = 60.0;

  static const Color colorPrimary = Color(0xFFFFFFFF);
  static const Color colorSecondary = Color(0xFFD4D4D4);
  static const Color colorMuted = Color(0xFF7A7A7A);

  static const backgroundColor = Color(0xCC0F172A);
  static const fullFocusColor = Color(0xFF38BDF8);
  static const focusColor = Color(0x6638BDF8);
  static const timeWarningColor = Color(0xFFFF5722);
  static const Color divider = Color(0xFF616161);
  static const Color errColor = Color(0xFFF44336);

  static const TextStyle boldTextStyle = TextStyle(
    color: AppTheme.colorPrimary,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle extraLightTextStyle = TextStyle(
    color: AppTheme.colorPrimary,
    fontWeight: FontWeight.w300,
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scrollbarTheme: ScrollbarThemeData(
      trackColor: WidgetStateProperty.all(Colors.white10),
      trackBorderColor: WidgetStateProperty.all(Colors.white10),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: fullFocusColor, width: 2);
          }
          return BorderSide(color: Colors.white30, width: 1);
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
        ),
      ),
    ),
  );

  static const TextStyle infoTextStyle = TextStyle(
    color: Colors.white70,
    fontSize: 11,
    fontWeight: FontWeight.w300,
    letterSpacing: 0.5,
  );

  static const TextStyle noDataTextStyle = TextStyle(
    color: AppTheme.colorSecondary,
  );

  static const TextStyle detailsChannelNameStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: colorPrimary,
  );
  static const TextStyle detailsProgramTitleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: colorPrimary,
    shadows: [Shadow(blurRadius: 3, color: Colors.black)],
  );
  static const TextStyle detailsProgramTimeStyle = TextStyle(
    fontSize: 16,
    color: colorSecondary,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle detailsProgramDescriptionStyle = TextStyle(
    fontSize: 16,
    height: 1.5,
    color: colorSecondary,
  );
  static const TextStyle programsChannelNameStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: colorPrimary,
  );
  static const TextStyle dateSelectorSelectedDayStyle = TextStyle(
    color: colorPrimary,
    fontWeight: FontWeight.bold,
    fontSize: 12,
  );
  static const TextStyle dateSelectorUnselectedDayStyle = TextStyle(
    color: colorSecondary,
    fontWeight: FontWeight.normal,
    fontSize: 12,
  );

  static const TextStyle indicatorSelectedLabelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle indicatorUnselectedLabelStyle = TextStyle(
    fontSize: 14,
  );

  static const TextStyle programListItemTimeStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: colorSecondary,
  );
  static final TextStyle programListPassedItemTimeStyle =
      programListItemTimeStyle.copyWith(
        color: colorSecondary.withValues(alpha: 0.7),
      );
  static const TextStyle timelineTimeStyle = TextStyle(
    fontSize: 16,
    color: colorSecondary,
    fontWeight: FontWeight.w500,
  );

  static BoxDecoration programDetailsGradientDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.center,
      colors: [Colors.black, Colors.transparent],
    ),
  );
}

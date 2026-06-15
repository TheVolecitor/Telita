import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../flutter_tv_media3.dart';

/// Represents the settings for displaying the clock over the video player.
///
/// This class contains parameters that define the position, appearance, and colors
/// of the clock widget in the player's UI.
///
/// A `ClockSettings` object is passed to the player before it is created.
/// The application can save these settings (e.g., in SharedPreferences)
/// to restore the user's choice on subsequent launches. If the settings
/// are not provided, the player uses default values.
///
/// Objects of this class are immutable. To create a modified
/// copy, use the [copyWith] method.
class ClockSettings extends Equatable {
  /// Determines where the clock will be located on the screen.
  /// See [ClockPosition] for possible values.
  final ClockPosition clockPosition;

  /// A flag indicating whether to display a border around the clock.
  final bool showClockBorder;

  /// A flag indicating whether to display a background under the clock.
  final bool showClockBackground;

  /// The color of the clock text.
  final ExtendedColors clockColor;

  /// The color of the clock's background.
  final ExtendedColors backgroundColor;

  /// The color of the clock's border.
  final ExtendedColors borderColor;

  const ClockSettings({
    this.clockPosition = ClockPosition.none,
    this.showClockBorder = true,
    this.showClockBackground = true,
    this.clockColor = ExtendedColors.lightGray,
    this.backgroundColor = ExtendedColors.black50,
    this.borderColor = ExtendedColors.white25,
  });

  @override
  List<Object> get props => [
    clockPosition,
    showClockBorder,
    showClockBackground,
    clockColor,
    backgroundColor,
    borderColor,
  ];

  ClockSettings copyWith({
    ClockPosition? clockPosition,
    bool? showClockBorder,
    bool? showClockBackground,
    ExtendedColors? clockColor,
    bool? randomPlay,
    String? opensubtitlesToken,
    ExtendedColors? backgroundColor,
    ExtendedColors? borderColor,
  }) {
    return ClockSettings(
      clockPosition: clockPosition ?? this.clockPosition,
      showClockBorder: showClockBorder ?? this.showClockBorder,
      showClockBackground: showClockBackground ?? this.showClockBackground,
      clockColor: clockColor ?? this.clockColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clockPosition': clockPosition.index,
      'showClockBorder': showClockBorder,
      'showClockBackground': showClockBackground,
      'clockColor': clockColor.index,
      'backgroundColor': backgroundColor.index,
      'borderColor': borderColor.index,
    };
  }

  factory ClockSettings.fromMap(Map<String, dynamic> map) {
    return ClockSettings(
      clockPosition: ClockPosition.values[map['clockPosition'] as int? ?? 4],
      showClockBorder: map['showClockBorder'] as bool? ?? true,
      showClockBackground: map['showClockBackground'] as bool? ?? true,
      clockColor: ExtendedColors.values[map['clockColor'] as int? ?? 3],
      backgroundColor:
          ExtendedColors.values[map['backgroundColor'] as int? ?? 6],
      borderColor: ExtendedColors.values[map['borderColor'] as int? ?? 5],
    );
  }

  @override
  String toString() {
    return '''ClockSettings{
      clockPosition: $clockPosition, 
      showClockBorder: $showClockBorder, 
      showClockBackground: $showClockBackground, 
      clockColor: $clockColor, 
      backgroundColor: $backgroundColor, 
      borderColor: $borderColor
    }''';
  }
}

/// Defines the possible positions of the clock on the screen.
///
/// Each position (except `none` and `random`) corresponds to one of the screen corners
/// and contains the respective offsets (`top`, `bottom`, `left`, `right`) for
/// positioning.
enum ClockPosition {
  /// Top right corner.
  topRight("clockPositionTopRight", 10.0, null, 10.0, null),

  /// Bottom right corner.
  bottomRight("clockPositionBottomRight", 10.0, null, null, 10.0),

  /// Top left corner.
  topLeft("clockPositionTopLeft", null, 10.0, 10.0, null),

  /// Bottom left corner.
  bottomLeft("clockPositionBottomLeft", null, 10.0, null, 10.0),

  /// A random position in one of the four corners.
  /// The position is chosen on each launch.
  random("clockPositionRandom", null, null, null, null),

  /// The clock is not displayed.
  none("clockPositionNone", null, null, null, null);

  const ClockPosition(this.key, this.right, this.left, this.top, this.bottom);

  /// The key for localizing the position name.
  final String key;

  /// The localized name of the position for display in the UI.
  String get title => OverlayLocalizations.get(key);

  /// The offset from the right edge.
  final double? right;

  /// The offset from the left edge.
  final double? left;

  /// The offset from the top edge.
  final double? top;

  /// The offset from the bottom edge.
  final double? bottom;

  /// A static method to change the position in the list (forward/backward).
  /// Used in the settings menu.
  static ClockPosition changeValue({
    required int index,
    required int direction,
  }) {
    final length = ClockPosition.values.length;
    final newIndex = (index + direction + length) % length;
    return ClockPosition.values[newIndex];
  }

  /// A static method to get a random corner position.
  static ClockPosition getRandomPosition() {
    const cornerPositions = [
      ClockPosition.topLeft,
      ClockPosition.topRight,
      ClockPosition.bottomLeft,
      ClockPosition.bottomRight,
    ];
    return cornerPositions[Random().nextInt(cornerPositions.length)];
  }
}

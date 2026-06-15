import '../const/basic_colors.dart';
import '../const/extended_colors.dart';

/// Represents the visual style settings for subtitles.
///
/// This object is passed to the player before it is created. The application can
/// save these settings (e.g., in SharedPreferences) to restore the
/// user's choice on subsequent launches. If the settings are not provided,
/// the player uses system or default values.
class SubtitleStyle {
  SubtitleStyle({
    this.applyEmbeddedStyles = true,
    this.foregroundColor = BasicColors.white,
    this.backgroundColor = ExtendedColors.transparent,
    this.windowColor = ExtendedColors.transparent,
    this.edgeType = SubtitleEdgeType.dropShadow,
    this.edgeColor = BasicColors.black,
    this.textSizeFraction = 1.0,
    this.bottomPadding,
    this.leftPadding,
    this.rightPadding,
    this.topPadding,
  });

  /// The main color of the subtitle text.
  final BasicColors? foregroundColor;

  /// The background color for the subtitle text.
  final ExtendedColors? backgroundColor;

  /// The type of outline/shadow for the text.
  final SubtitleEdgeType? edgeType;

  /// The color of the outline/shadow.
  final BasicColors? edgeColor;

  /// The text size fraction. Used as a multiplier for the system font size.
  final double? textSizeFraction;

  /// A flag indicating whether to apply styles embedded
  /// directly in the subtitle track (if available).
  final bool? applyEmbeddedStyles;

  /// The color of the background window (caption box) behind the subtitles.
  final ExtendedColors? windowColor;

  /// The bottom padding for the subtitle area.
  final int? bottomPadding;

  /// The left padding for the subtitle area.
  final int? leftPadding;

  /// The right padding for the subtitle area.
  final int? rightPadding;

  /// The top padding for the subtitle area.
  final int? topPadding;

  Map<String, dynamic> toMap() {
    return {
      'foregroundColor': foregroundColor?.hexString,
      'backgroundColor': backgroundColor?.hexString,
      'edgeType': edgeType?.index,
      'edgeColor': edgeColor?.hexString,
      'textSizeFraction': textSizeFraction,
      'applyEmbeddedStyles': applyEmbeddedStyles,
      'windowColor': windowColor?.hexString,
      'bottomPadding': bottomPadding,
      'leftPadding': leftPadding,
      'rightPadding': rightPadding,
      'topPadding': topPadding,
    };
  }

  factory SubtitleStyle.fromMap(Map<dynamic, dynamic> map) {
    return SubtitleStyle(
      foregroundColor: BasicColors.fromHex(map['foregroundColor'] as String?),
      backgroundColor: ExtendedColors.fromHex(
        map['backgroundColor'] as String?,
      ),
      edgeType: SubtitleEdgeType.values[map['edgeType'] as int],
      edgeColor: BasicColors.fromHex(map['edgeColor'] as String?),
      textSizeFraction: map['textSizeFraction'] as double,
      applyEmbeddedStyles: map['applyEmbeddedStyles'] as bool,
      windowColor: ExtendedColors.fromHex(map['windowColor'] as String?),
      bottomPadding: map['bottomPadding'] as int?,
      leftPadding: map['leftPadding'] as int?,
      rightPadding: map['rightPadding'] as int?,
      topPadding: map['topPadding'] as int?,
    );
  }

  @override
  String toString() {
    return '''SubtitleStyle{
      foregroundColor: $foregroundColor, 
      backgroundColor: $backgroundColor, 
      edgeType: $edgeType, 
      edgeColor: $edgeColor, 
      textSizeFraction: $textSizeFraction, 
      applyEmbeddedStyles: $applyEmbeddedStyles, 
      windowColor: $windowColor, 
      bottomPadding: $bottomPadding, 
      leftPadding: $leftPadding, 
      rightPadding: $rightPadding, 
      topPadding: $topPadding
    }''';
  }

  SubtitleStyle copyWith({
    BasicColors? foregroundColor,
    ExtendedColors? backgroundColor,
    SubtitleEdgeType? edgeType,
    BasicColors? edgeColor,
    double? textSizeFraction,
    bool? applyEmbeddedStyles,
    ExtendedColors? windowColor,
    int? bottomPadding,
    int? leftPadding,
    int? rightPadding,
    int? topPadding,
  }) {
    return SubtitleStyle(
      foregroundColor: foregroundColor ?? this.foregroundColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      edgeType: edgeType ?? this.edgeType,
      edgeColor: edgeColor ?? this.edgeColor,
      textSizeFraction: textSizeFraction ?? this.textSizeFraction,
      applyEmbeddedStyles: applyEmbeddedStyles ?? this.applyEmbeddedStyles,
      windowColor: windowColor ?? this.windowColor,
      bottomPadding: bottomPadding ?? this.bottomPadding,
      leftPadding: leftPadding ?? this.leftPadding,
      rightPadding: rightPadding ?? this.rightPadding,
      topPadding: topPadding ?? this.topPadding,
    );
  }
}

/// Defines the type of visual effect for the edges of the subtitle text.
enum SubtitleEdgeType {
  /// No effect.
  none,

  /// Outline.
  outline,

  /// Drop shadow.
  dropShadow,

  /// Raised effect.
  raised,

  /// Depressed effect.
  depressed;

  static SubtitleEdgeType changeValue({
    required int index,
    required int direction,
  }) {
    final length = SubtitleEdgeType.values.length;
    final newIndex = (index + direction + length) % length;
    return SubtitleEdgeType.values[newIndex];
  }
}

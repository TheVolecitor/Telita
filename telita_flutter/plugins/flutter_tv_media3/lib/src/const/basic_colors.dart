import 'dart:ui';

enum BasicColors {
  white(Color(0xFFFFFFFF), '#FFFFFFFF'),
  yellow(Color(0xFFFFFF00), '#FFFFFF00'),
  black(Color(0xFF000000), '#FF000000'),
  cyan(Color(0xFF00FFFF), '#FF00FFFF'),
  green(Color(0xFF00FF00), '#FF00FF00'),
  magenta(Color(0xFFFF00FF), '#FFFF00FF'),
  red(Color(0xFFFF0000), '#FFFF0000'),
  blue(Color(0xFF0000FF), '#FF0000FF'),
  orange(Color(0xFFFFA500), '#FFFFA500'),
  blueViolet(Color(0xFF8A2BE2), '#FF8A2BE2'),
  greenYellow(Color(0xFFADFF2F), '#FFADFF2F'),
  khaki(Color(0xFFF0E68C), '#FFF0E68C'),
  lightBlue(Color(0xFFADD8E6), '#FFADD8E6'),
  lightPink(Color(0xFFFFB6C1), '#FFFFB6C1'),
  lightCyan(Color(0xFFE0FFFF), '#FFE0FFFF'),
  darkRed(Color(0xFF8B0000), '#FF8B0000'),
  darkGreen(Color(0xFF006400), '#FF006400'),
  darkBlue(Color(0xFF00008B), '#FF00008B'),
  indigo(Color(0xFF4B0082), '#FF4B0082'),
  darkSlateGray(Color(0xFF2F4F4F), '#FF2F4F4F');

  const BasicColors(this.color, this.hexString);

  final Color color;
  final String hexString;

  static BasicColors? fromColor(Color color) {
    for (BasicColors colorEnum in BasicColors.values) {
      if (colorEnum.color == color) {
        return colorEnum;
      }
    }
    return null;
  }

  static BasicColors? fromHex(String? hexString) {
    for (BasicColors colorEnum in BasicColors.values) {
      if (colorEnum.hexString.toUpperCase() == hexString?.toUpperCase()) {
        return colorEnum;
      }
    }
    return null;
  }

  static Map<Color, String> get colorMap {
    return Map.fromEntries(
      BasicColors.values.map((e) => MapEntry(e.color, e.hexString)),
    );
  }

  static List<Color> get allColors {
    return BasicColors.values.map((e) => e.color).toList();
  }

  static List<String> get allHexStrings {
    return BasicColors.values.map((e) => e.hexString).toList();
  }
}

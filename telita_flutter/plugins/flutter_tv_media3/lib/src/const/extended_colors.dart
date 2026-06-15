import 'dart:ui';

enum ExtendedColors {
  transparent(Color(0x00000000), '#00000000'),
  black25(Color(0x40000000), '#40000000'),
  black50(Color(0x80000000), '#80000000'),
  black75(Color(0xC0000000), '#C0000000'),
  black100(Color(0xFF000000), '#FF000000'),
  white25(Color(0x40FFFFFF), '#40FFFFFF'),
  white50(Color(0x80FFFFFF), '#80FFFFFF'),
  white100(Color(0xFFFFFFFF), '#FFFFFFFF'),
  offWhite(Color(0xFFEFEFEF), '#FFEFEFEF'),
  lightGray(Color(0xFFCCCCCC), '#FFCCCCCC'),
  gray(Color(0xFF888888), '#FF888888'),
  darkGray(Color(0xFF444444), '#FF444444'),
  veryDarkGray(Color(0xFF222222), '#FF222222'),
  semiTransparentGray(Color(0x80444444), '#80444444'),
  semiTransparentDarkBlue(Color(0x8000008B), '#8000008B'),
  semiTransparentDarkSlateGray(Color(0x802F4F4F), '#802F4F4F'),
  yellow(Color(0xFFFFFF00), '#FFFFFF00'),
  cyan(Color(0xFF00FFFF), '#FF00FFFF'),
  green(Color(0xFF00FF00), '#FF00FF00'),
  red(Color(0xFFFF0000), '#FFFF0000');

  const ExtendedColors(this.color, this.hexString);

  final Color color;
  final String hexString;

  static ExtendedColors? fromColor(Color color) {
    for (ExtendedColors colorEnum in ExtendedColors.values) {
      if (colorEnum.color == color) {
        return colorEnum;
      }
    }
    return null;
  }

  static ExtendedColors? fromHex(String? hexString) {
    for (ExtendedColors colorEnum in ExtendedColors.values) {
      if (colorEnum.hexString.toUpperCase() == hexString?.toUpperCase()) {
        return colorEnum;
      }
    }
    return null;
  }

  static Map<Color, String> get colorMap {
    return Map.fromEntries(
      ExtendedColors.values.map((e) => MapEntry(e.color, e.hexString)),
    );
  }

  static List<Color> get allColors {
    return ExtendedColors.values.map((e) => e.color).toList();
  }

  static List<String> get allHexStrings {
    return ExtendedColors.values.map((e) => e.hexString).toList();
  }
}

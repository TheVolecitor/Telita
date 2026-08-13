import 'dart:convert';

class CatalogConfig {
  List<String> order;
  List<String> hidden;
  Map<String, int> limits;

  CatalogConfig({
    List<String>? order,
    List<String>? hidden,
    Map<String, int>? limits,
  })  : order = order ?? [],
        hidden = hidden ?? [],
        limits = limits ?? {};

  factory CatalogConfig.fromJson(Map<String, dynamic> json) {
    return CatalogConfig(
      order: (json['order'] as List<dynamic>?)?.map((e) => e as String).toList(),
      hidden: (json['hidden'] as List<dynamic>?)?.map((e) => e as String).toList(),
      limits: (json['limits'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as int),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'hidden': hidden,
      'limits': limits,
    };
  }

  factory CatalogConfig.fromString(String jsonString) {
    if (jsonString.isEmpty) return CatalogConfig();
    try {
      return CatalogConfig.fromJson(jsonDecode(jsonString));
    } catch (e) {
      return CatalogConfig();
    }
  }

  String toStringConfig() {
    return jsonEncode(toJson());
  }
}

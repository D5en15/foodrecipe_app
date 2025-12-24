import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/category_model.dart';

class CategoryService {
  static List<dynamic>? _rawCache;
  static final Map<String, List<CategoryModel>> _localizedCache = {};
  static final Map<String, Map<String, String>> _nameMapCache = {};
  static final Map<String, Map<String, String>> _nameToIdCache = {};

  static Future<List<dynamic>> _loadRaw() async {
    if (_rawCache != null) return _rawCache!;
    final jsonString =
        await rootBundle.loadString("assets/data/categories.json");
    _rawCache = json.decode(jsonString) as List<dynamic>;
    return _rawCache!;
  }

  static String _localizedNameFor(
      Map<String, dynamic> json, String languageCode) {
    final translations =
        json['translations'] as Map<String, dynamic>? ?? const {};
    final langEntry = translations[languageCode];
    if (langEntry is Map && langEntry['name'] is String) {
      return langEntry['name'] as String;
    }
    final enEntry = translations['en'];
    if (enEntry is Map && enEntry['name'] is String) {
      return enEntry['name'] as String;
    }
    for (final entry in translations.values) {
      if (entry is Map && entry['name'] is String) {
        return entry['name'] as String;
      }
    }
    return json['name']?.toString() ?? json['id']?.toString() ?? '';
  }

  // โหลด categories จากไฟล์ JSON
  static Future<List<CategoryModel>> loadCategories(
      String languageCode) async {
    if (_localizedCache.containsKey(languageCode)) {
      return _localizedCache[languageCode]!;
    }

    final data = await _loadRaw();

    final categories = data
        .map((item) => item as Map<String, dynamic>)
        .map(
          (item) => CategoryModel(
            id: item['id'].toString(),
            name: _localizedNameFor(item, languageCode),
            image: item['image']?.toString() ?? '',
          ),
        )
        .toList();

    _localizedCache[languageCode] = categories;
    return categories;
  }

  static Future<Map<String, String>> loadCategoryNameMap(
      String languageCode) async {
    if (_nameMapCache.containsKey(languageCode)) {
      return _nameMapCache[languageCode]!;
    }
    final categories = await loadCategories(languageCode);
    final map = {
      for (final item in categories) item.id: item.name,
    };
    _nameMapCache[languageCode] = map;
    return map;
  }

  static Future<Map<String, String>> loadCategoryNameToIdMap(
      String languageCode) async {
    if (_nameToIdCache.containsKey(languageCode)) {
      return _nameToIdCache[languageCode]!;
    }

    final data = await _loadRaw();
    final map = <String, String>{};

    String normalize(String value) => value.trim();

    for (final entry in data) {
      final json = entry as Map<String, dynamic>;
      final id = json['id'].toString();
      final translations =
          json['translations'] as Map<String, dynamic>? ?? const {};

      void addName(String? raw) {
        if (raw == null) return;
        final normalized = normalize(raw);
        if (normalized.isEmpty) return;
        map[normalized] = id;
        map[normalized.toLowerCase()] = id;
      }

      addName(_localizedNameFor(json, languageCode));
      addName(id);
      for (final value in translations.values) {
        if (value is Map && value['name'] is String) {
          addName(value['name'] as String);
        }
      }
    }

    _nameToIdCache[languageCode] = map;
    return map;
  }

  static String? findCategoryIdForName(
    String name,
    Map<String, String> nameToIdMap,
  ) {
    if (name.trim().isEmpty) return null;
    return nameToIdMap[name] ?? nameToIdMap[name.toLowerCase()];
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/recipe_model.dart';
import 'category_service.dart';

class RecipeWithCategories {
  final RecipeModel recipe;
  final List<String> categoryIds;
  final String cuisineId;

  RecipeWithCategories({
    required this.recipe,
    required this.categoryIds,
    required this.cuisineId,
  });
}

class RecipeService {
  static const _countryPrefix = 'assets/data/country/';
  static const _cuisinesIndexPath = 'assets/data/cuisines.json';

  static List<String>? _cuisineIds;
  static final Map<String, List<RecipeWithCategories>> _cacheByLang = {};

  static Future<List<String>> _loadCuisineIds() async {
    if (_cuisineIds != null) return _cuisineIds!;
    try {
      final jsonString = await rootBundle.loadString(_cuisinesIndexPath);
      final List data = json.decode(jsonString) as List;
      _cuisineIds = data
          .map((entry) => (entry as Map<String, dynamic>)['id'])
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      print('❌ ERROR loading cuisines index: $e');
      _cuisineIds = [];
    }
    return _cuisineIds!;
  }

  static Future<List<dynamic>?> _tryLoadCountryFile(String path) async {
    try {
      debugPrint('🔎 Loading recipe asset: $path');
      final jsonString = await rootBundle.loadString(path);
      return json.decode(jsonString) as List<dynamic>;
    } catch (e) {
      debugPrint('⚠️ Failed to load recipe asset $path -> $e');
      return null;
    }
  }

  static Future<List<dynamic>?> _loadCuisineData(
      String cuisineId, String languageCode) async {
    final primary = '$_countryPrefix${cuisineId}_$languageCode.json';
    final primaryData = await _tryLoadCountryFile(primary);
    if (primaryData != null) {
      return primaryData;
    }
    if (languageCode != 'en') {
      final fallback = '$_countryPrefix${cuisineId}_en.json';
      final fallbackData = await _tryLoadCountryFile(fallback);
      if (fallbackData != null) {
        return fallbackData;
      }
    }
    final legacy = '$_countryPrefix${cuisineId}.json';
    final legacyData = await _tryLoadCountryFile(legacy);
    if (legacyData != null) {
      return legacyData;
    }
    print('⚠️ Missing recipe file for cuisine "$cuisineId" (lang: $languageCode)');
    return null;
  }

  static Future<List<RecipeWithCategories>> _loadEntries(
      String languageCode) async {
    if (_cacheByLang.containsKey(languageCode)) {
      return _cacheByLang[languageCode]!;
    }

    final nameToIdMap =
        await CategoryService.loadCategoryNameToIdMap(languageCode);
    final List<RecipeWithCategories> entries = [];
    final cuisines = await _loadCuisineIds();

    for (final cuisineId in cuisines) {
      final rawList = await _loadCuisineData(cuisineId, languageCode);
      if (rawList == null) continue;
      for (final item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        final recipe = RecipeModel.fromJson(item);
        final categoryIds = <String>[];
        for (final categoryName in recipe.categories) {
          final id = CategoryService.findCategoryIdForName(
            categoryName,
            nameToIdMap,
          );
          if (id != null && !categoryIds.contains(id)) {
            categoryIds.add(id);
          }
        }
        entries.add(
          RecipeWithCategories(
            recipe: recipe,
            categoryIds: categoryIds,
            cuisineId: cuisineId,
          ),
        );
      }
    }

    _cacheByLang[languageCode] = entries;
    return entries;
  }

  /// โหลดเฉพาะหมวดเดียว
  static Future<List<RecipeModel>> loadRecipes({
    required String languageCode,
    required String categoryId,
  }) async {
    final entries = await _loadEntries(languageCode);
    return entries
        .where((entry) => entry.categoryIds.contains(categoryId))
        .map((entry) => entry.recipe)
        .toList();
  }

  /// โหลดทั้งหมด + รู้ว่าเมนูอยู่หมวดไหน
  /// return เป็น List<Map>
  /// [
  ///   { "categoryId": "drink", "recipe": RecipeModel },
  /// ]
  static Future<List<Map<String, dynamic>>> loadAllRecipesWithCategories(
      String lang) async {
    final entries = await _loadEntries(lang);
    final List<Map<String, dynamic>> all = [];

    for (final entry in entries) {
      if (entry.categoryIds.isEmpty) continue;
      for (final categoryId in entry.categoryIds) {
        all.add({
          "categoryId": categoryId,
          "cuisineId": entry.cuisineId,
          "recipe": entry.recipe,
        });
      }
    }

    return all;
  }

  static Future<List<RecipeWithCategories>> loadAllRecipeEntries(
      String lang) async {
    final entries = await _loadEntries(lang);
    return entries
        .map(
          (entry) => RecipeWithCategories(
            recipe: entry.recipe,
            categoryIds: List<String>.from(entry.categoryIds),
            cuisineId: entry.cuisineId,
          ),
        )
        .toList();
  }

  static Future<List<RecipeWithCategories>> loadSampleEntries({
    required String languageCode,
    int count = 10,
  }) async {
    List<RecipeWithCategories> entries =
        List<RecipeWithCategories>.from(await _loadEntries(languageCode));
    if (entries.isEmpty && languageCode != 'en') {
      entries =
          List<RecipeWithCategories>.from(await _loadEntries('en'));
    }
    entries.shuffle();
    if (entries.length > count) {
      entries = entries.sublist(0, count);
    }
    return entries;
  }
}

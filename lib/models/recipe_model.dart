import 'dart:convert';
import 'dart:ui';

class RecipeModel {
  final String id;
  final String title;
  final String? titleEn;
  final String? titleTh;
  final String image;
  final String? prepTime;
  final String? cookTime;
  final String? totalTime;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> categories;

  RecipeModel({
    required this.id,
    required this.title,
    required this.image,
    required this.prepTime,
    required this.cookTime,
    required this.totalTime,
    required this.ingredients,
    required this.steps,
    required this.categories,
    this.titleEn,
    this.titleTh,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    return RecipeModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      titleEn: json['title_en']?.toString(),
      titleTh: json['title_th']?.toString(),
      image: json['image'] ?? 'assets/images/no-image.png',
      prepTime: json['prep_time']?.toString(),
      cookTime: json['cook_time']?.toString(),
      totalTime: json['total_time']?.toString(),
      ingredients: json['ingredients'] != null
          ? List<String>.from(json['ingredients'])
          : <String>[],
      steps: json['steps'] != null
          ? List<String>.from(json['steps'])
          : <String>[],
      categories: json['categories'] != null
          ? List<String>.from(
              (json['categories'] as List).map((e) => e.toString()))
          : <String>[],
    );
  }

  static List<RecipeModel> fromJsonList(String jsonString) {
    final list = json.decode(jsonString) as List;
    return list.map((e) => RecipeModel.fromJson(e)).toList();
  }

  String displayTitle(Locale locale) {
    final languageCode = locale.languageCode;
    if ((titleEn?.trim().isNotEmpty ?? false) ||
        (titleTh?.trim().isNotEmpty ?? false)) {
      if (languageCode == 'th') {
        return (titleTh?.trim().isNotEmpty == true
                ? titleTh!.trim()
                : (titleEn ?? title))
            .trim();
      }
      return (titleEn?.trim().isNotEmpty == true
              ? titleEn!.trim()
              : (titleTh ?? title))
          .trim();
    }
    return RecipeTitleHelper.pickTitleForLocale(title, locale);
  }
}

class RecipeTitleHelper {
  static final RegExp _parenRegex = RegExp(r'^(.*?)\s*\((.*?)\)\s*$');

  static String pickTitleForLocale(String raw, Locale locale) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;

    final match = _parenRegex.firstMatch(trimmed);
    if (match != null) {
      final outside = (match.group(1) ?? '').trim();
      final inside = (match.group(2) ?? '').trim();

      final isOutsideEnglish = _looksEnglish(outside);
      final isInsideEnglish = _looksEnglish(inside);
      final isThai = locale.languageCode == 'th';

      if (isThai) {
        if (!isOutsideEnglish && outside.isNotEmpty) return outside;
        if (!isInsideEnglish && inside.isNotEmpty) return inside;
        return outside.isNotEmpty ? outside : inside;
      } else {
        if (isOutsideEnglish && outside.isNotEmpty) return outside;
        if (isInsideEnglish && inside.isNotEmpty) return inside;
        return outside.isNotEmpty ? outside : inside;
      }
    }

    return trimmed;
  }

  static bool _looksEnglish(String value) {
    if (value.isEmpty) return false;
    final alphaOnly = value.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return alphaOnly.isNotEmpty;
  }
}

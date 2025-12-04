import 'package:flutter/services.dart';
import '../models/recipe_model.dart';

class RecipeService {
  static const recipeFiles = [
    "maincourse",
    "dessert",
    "seafood",
    "protein",
    "salad_and_healthy",
    "snack_and_appetizers",
    "drink",
    "noodles",
    "soap_and_curry",
  ];

  /// โหลดเฉพาะหมวดเดียว
  static Future<List<RecipeModel>> loadRecipes({
    required String languageCode,
    required String categoryId,
  }) async {
    final path = "assets/data/recipes_$languageCode/$categoryId.json";

    final jsonString = await rootBundle.loadString(path);
    return RecipeModel.fromJsonList(jsonString);
  }

  /// โหลดทั้งหมด + รู้ว่าเมนูนั้นอยู่ไฟล์อะไร (หมวดอะไร)
  /// return เป็น List<Map>
  /// [
  ///   { "file": "drink.json", "recipe": RecipeModel },
  ///   { "file": "noodles.json", "recipe": RecipeModel },
  /// ]
  static Future<List<Map<String, dynamic>>> loadAllRecipesWithFile(
      String lang) async {
    List<Map<String, dynamic>> all = [];

    for (final file in recipeFiles) {
      final path = "assets/data/recipes_$lang/$file.json";

      try {
        final jsonString = await rootBundle.loadString(path);
        final list = RecipeModel.fromJsonList(jsonString);

        for (final r in list) {
          all.add({
            "file": "$file.json",
            "recipe": r,
          });
        }
      } catch (e) {
        print("⚠ ไม่พบไฟล์หรือโหลดไม่ได้: $path");
      }
    }

    return all;
  }
}

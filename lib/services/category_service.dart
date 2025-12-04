import 'package:flutter/services.dart';
import '../models/category_model.dart';

class CategoryService {
  // โหลด categories จากไฟล์ JSON
  static Future<List<CategoryModel>> loadCategories(String languageCode) async {
    final path = "assets/data/categories_${languageCode}.json";
    final jsonString = await rootBundle.loadString(path);

    return CategoryModel.fromJsonList(jsonString);
  }
}

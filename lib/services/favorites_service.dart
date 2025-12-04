import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FavoritesService extends ChangeNotifier {
  /// เก็บเฉพาะ recipeId ที่ถูกกด favorite
  final Set<String> _favoriteIds = {};

  Set<String> get favoriteIds => _favoriteIds;

  /// ⭐ โหลด favorites จาก asset (runtime only)
  Future<void> loadFavorites() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/favorites.json');

      final List<dynamic> decoded = json.decode(jsonString);

      _favoriteIds
        ..clear()
        ..addAll(decoded.map((e) => e.toString()));

      notifyListeners();
    } catch (e) {
      debugPrint("⚠️ ไม่มีไฟล์ favorites.json หรืออ่านไม่ได้ → ใช้ค่าเริ่มต้น");
    }
  }

  /// ⭐ toggle favorite เปิด/ปิด
  void toggleFavorite(String recipeId) {
    if (_favoriteIds.contains(recipeId)) {
      _favoriteIds.remove(recipeId);
    } else {
      _favoriteIds.add(recipeId);
    }

    notifyListeners();
  }

  /// ✔️ ใช้สำหรับเช็คว่าชอบไหม
  bool isFavorite(String recipeId) {
    return _favoriteIds.contains(recipeId);
  }
}

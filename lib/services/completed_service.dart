import 'package:flutter/foundation.dart';
import '../models/recipe_model.dart';

class CompletedRecipe {
  final String id;
  final String title;
  final String image;
  final String? categoryId;
  final String? totalTime;

  CompletedRecipe({
    required this.id,
    required this.title,
    required this.image,
    this.categoryId,
    this.totalTime,
  });
}

class CompletedService extends ChangeNotifier {
  final List<CompletedRecipe> _completed = [];

  List<CompletedRecipe> get completed => List.unmodifiable(_completed);

  void addCompleted(RecipeModel recipe, {String? categoryId}) {
    _completed.removeWhere((item) => item.id == recipe.id);
    _completed.insert(
      0,
      CompletedRecipe(
        id: recipe.id,
        title: recipe.title,
        image: recipe.image,
        categoryId: categoryId,
        totalTime: recipe.totalTime,
      ),
    );

    // limit list size to avoid runaway memory
    if (_completed.length > 20) {
      _completed.removeRange(20, _completed.length);
    }

    notifyListeners();
  }
}

import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/recipes_list_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/cooking_complete_screen.dart';
import 'screens/finishcook_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/countdown_screen.dart';

class Routes {
  static const String welcome = '/';
  static const String home = '/home';
  static const String categories = '/categories';
  static const String recipes = '/recipes';
  static const String recipeDetail = '/recipe-detail';
  static const String favorites = '/favorites';
  static const String cookingComplete = '/cooking-complete';
  static const String finishCook = '/finish-cook';
  static const String loading = '/loading';
  static const String countdown = '/countdown';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {

      case Routes.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case Routes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case Routes.loading:
        return MaterialPageRoute(builder: (_) => const LoadingScreen());

      case Routes.categories:
        return MaterialPageRoute(builder: (_) => const CategoriesScreen());

      case Routes.recipes:
        return MaterialPageRoute(
          builder: (_) => const RecipesListScreen(),
          settings: settings,   // ⭐ FIXED
        );

      case Routes.recipeDetail:
        return MaterialPageRoute(
          builder: (_) => const RecipeDetailScreen(),
          settings: settings,   // ⭐ ถ้าหน้านี้รับ arguments เช่นกัน
        );

      case Routes.favorites:
        return MaterialPageRoute(builder: (_) => const FavoritesScreen());

      case Routes.cookingComplete:
        return MaterialPageRoute(builder: (_) => const CookingCompleteScreen());

      case Routes.finishCook:
        return MaterialPageRoute(builder: (_) => const FinishCookScreen());

      case Routes.countdown:
        return MaterialPageRoute(builder: (_) => const CountdownScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text("Page not found"),
            ),
          ),
        );
    }
  }
}

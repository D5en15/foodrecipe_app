import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../models/recipe_model.dart';
import '../app_router.dart';
import '../theme/app_colors.dart';
import '../database/app_database.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<_FavoriteItem> favoriteRecipes = [];
  bool isLoading = true;

  final List<String> categories = [
    "maincourse",
    "dessert",
    "drink",
    "noodles",
    "protein",
    "salad_and_healthy",
    "seafood",
    "snack_and_appetizers",
    "soap_and_curry",
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final favIds = await AppDatabase.instance.getFavoriteIds();

    final strings = AppLocalizations.of(context);
    final lang = strings?.locale.languageCode ?? "th";

    List<_FavoriteItem> loaded = [];

    for (final cat in categories) {
      final path = "assets/data/recipes_$lang/$cat.json";
      final jsonStr = await rootBundle.loadString(path);
      final List data = json.decode(jsonStr);

      for (final item in data) {
        if (favIds.contains(item["id"])) {
          loaded.add(
            _FavoriteItem(
              recipe: RecipeModel.fromJson(item),
              categoryId: cat,
            ),
          );
        }
      }
    }

    setState(() {
      favoriteRecipes = loaded;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final locale = strings.locale;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          strings.t('favorite_page_title'),
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : favoriteRecipes.isEmpty
              ? _EmptyState(strings: strings)
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  itemCount: favoriteRecipes.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 30, thickness: 1, color: AppColors.accent),
                  itemBuilder: (context, index) {
                    final r = favoriteRecipes[index];
                    return Row(
                      children: [
                        // รูป
                        ClipOval(
                          child: Image.asset(
                            r.image,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(
                              width: 90,
                              height: 90,
                              color: AppColors.background,
                              child: const Icon(Icons.broken_image,
                                  color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // ข้อมูล
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                Routes.recipeDetail,
                                arguments: {
                                  "id": r.id,
                                  "category": r.categoryId,
                                },
                              ).then((_) => loadFavorites());
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.recipe.displayTitle(locale),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  r.totalTime ?? "-",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            AppDatabase.instance.toggleFavorite(r.id).then((_) {
                              loadFavorites();
                            });
                          },
                          icon: Icon(
                            Icons.favorite,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations strings;

  const _EmptyState({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 60, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            strings.t('empty_state_title'),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.t('empty_state_message'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteItem {
  final RecipeModel recipe;
  final String categoryId;

  _FavoriteItem({required this.recipe, required this.categoryId});

  String get id => recipe.id;
  String get title => recipe.title;
  String? get totalTime => recipe.totalTime;
  String get image => recipe.image;
}

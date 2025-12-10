import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_router.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../database/app_database.dart';
import '../services/recipe_service.dart';
import '../models/recipe_model.dart';

class FinishCookScreen extends StatefulWidget {
  const FinishCookScreen({super.key});

  @override
  State<FinishCookScreen> createState() => _FinishCookScreenState();
}

class _FinishCookScreenState extends State<FinishCookScreen> {
  List<RecipeModel> completedRecipes = [];
  bool isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCompleted();
  }

  Future<void> _loadCompleted() async {
    final ids = await AppDatabase.instance.getCompletedIds();
    final lang = AppLocalizations.of(context)?.locale.languageCode ?? "th";

    if (ids.isEmpty) {
      setState(() {
        completedRecipes = [];
        isLoading = false;
      });
      return;
    }

    try {
      final entries = await RecipeService.loadAllRecipeEntries(lang);
      final lookup = {
        for (final entry in entries) entry.recipe.id: entry.recipe,
      };
      final recipes = ids
          .map((id) => lookup[id])
          .whereType<RecipeModel>()
          .toList();
      setState(() {
        completedRecipes = recipes;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        completedRecipes = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          strings.t('completed_page_title'),
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : completedRecipes.isEmpty
              ? _EmptyState(strings: strings)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  itemCount: completedRecipes.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 30,
                    thickness: 1,
                    color: AppColors.accent,
                  ),
                  itemBuilder: (context, index) {
                    final r = completedRecipes[index];
                    return Row(
                      children: [
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
                        Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            Routes.recipeDetail,
                            arguments: {
                              "id": r.id,
                              "category": null,
                            },
                          ).then((_) => _loadCompleted());
                        },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
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
                        const Icon(Icons.check_circle, color: AppColors.primary),
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
          const Icon(Icons.assignment_turned_in_outlined,
              size: 60, color: AppColors.primary),
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

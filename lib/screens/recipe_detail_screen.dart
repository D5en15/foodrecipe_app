import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_router.dart';
import '../l10n/app_localizations.dart';
import '../models/recipe_model.dart';
import '../services/recipe_service.dart';
import '../theme/app_colors.dart';
import '../database/app_database.dart';
import '../services/category_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  RecipeModel? recipe;
  String? recipeId;
  String? categoryId;
  String? _categoryNamesLang;
  Map<String, String> _categoryNames = {};
  bool _isFavorite = false;
  bool _isCompleted = false;
  Set<int> _checkedIngredients = {};
  Set<int> _checkedSteps = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map?;

    recipeId = args?['id'];
    categoryId = args?['category'];

    loadRecipe();
  }

  Future<void> _loadStatuses(String recipeId) async {
    final fav = await AppDatabase.instance.isFavorite(recipeId);
    final comp = await AppDatabase.instance.isCompleted(recipeId);
    if (!mounted) return;
    setState(() {
      _isFavorite = fav;
      _isCompleted = comp;
      if (comp && recipe != null) {
        _checkedIngredients = Set<int>.from(
          List.generate(recipe!.ingredients.length, (i) => i),
        );
        _checkedSteps = Set<int>.from(
          List.generate(recipe!.steps.length, (i) => i),
        );
      }
    });
  }

  Future<void> _loadCategoryNames(String lang) async {
    if (_categoryNamesLang == lang && _categoryNames.isNotEmpty) return;
    try {
      _categoryNames = await CategoryService.loadCategoryNameMap(lang);
      _categoryNamesLang = lang;
    } catch (_) {
      _categoryNames = {};
      _categoryNamesLang = null;
    }
  }

  void _resetChecklistForRecipe() {
    _checkedIngredients = {};
    _checkedSteps = {};
  }

  void _toggleIngredient(int index) {
    setState(() {
      if (_checkedIngredients.contains(index)) {
        _checkedIngredients.remove(index);
      } else {
        _checkedIngredients.add(index);
      }
    });
  }

  Future<void> _toggleFavoriteState() async {
    if (recipe == null) return;
    final newState = await AppDatabase.instance.toggleFavorite(recipe!.id);
    await AppDatabase.instance.debugCheckDatabase();
    if (!mounted) return;
    setState(() {
      _isFavorite = newState;
    });
  }

  void _toggleStep(int index) {
    setState(() {
      if (_checkedSteps.contains(index)) {
        _checkedSteps.remove(index);
      } else {
        _checkedSteps.add(index);
      }
    });
  }

  bool get _isChecklistComplete {
    if (_isCompleted) return true;
    final ingTotal = recipe?.ingredients.length ?? 0;
    final stepTotal = recipe?.steps.length ?? 0;
    final ingDone = ingTotal == 0 || _checkedIngredients.length == ingTotal;
    final stepDone = stepTotal == 0 || _checkedSteps.length == stepTotal;
    return ingDone && stepDone;
  }

  Future<void> loadRecipe() async {
    if (recipeId == null) return;

    final lang = AppLocalizations.of(context)?.locale.languageCode ?? "th";
    await _loadCategoryNames(lang);

    RecipeModel? found;
    String? resolvedCategoryId = categoryId;

    try {
      if (categoryId != null) {
        final list = await RecipeService.loadRecipes(
          languageCode: lang,
          categoryId: categoryId!,
        );
        for (final r in list) {
          if (r.id == recipeId) {
            found = r;
            break;
          }
        }
      }

      if (found == null) {
        final all = await RecipeService.loadAllRecipesWithCategories(lang);
        for (final entry in all) {
          final r = entry["recipe"] as RecipeModel;
          if (r.id == recipeId) {
            found = r;
            resolvedCategoryId = entry["categoryId"] as String?;
            break;
          }
        }
      }
    } catch (e) {
      print("❌ ERROR loading recipe: $e");
    }

    if (!mounted) return;

    setState(() {
      recipe = found;
      categoryId = resolvedCategoryId;
      _resetChecklistForRecipe();
    });
    if (found != null) {
      _loadStatuses(found.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recipe == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final strings = AppLocalizations.of(context)!;
    final locale = strings.locale;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HeaderImage(
                    imagePath: recipe!.image,
                    isFavorite: _isFavorite,
                    onBack: () => Navigator.pop(context),
                    onFavoriteToggle: _toggleFavoriteState,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          recipe!.displayTitle(locale),
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _TimeChipsRow(
                          strings: strings,
                          recipe: recipe!,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                strings.t('detail_timer_label'),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side:
                                      const BorderSide(color: AppColors.primary),
                                  backgroundColor:
                                      AppColors.accent.withOpacity(0.6),
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(
                                      context, Routes.countdown);
                                },
                                icon: const Icon(Icons.timer),
                                label: Text(
                                  strings.t('timer'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          strings.t('recipe_ingredients'),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recipe!.ingredients
                            .asMap()
                            .entries
                            .map(
                              (e) => _ChecklistTile(
                                index: e.key,
                                text: e.value,
                                checked:
                                    _checkedIngredients.contains(e.key),
                                onToggle: () => _toggleIngredient(e.key),
                              ),
                            )
                            .toList(),
                        const SizedBox(height: 24),
                        Text(
                          strings.t('recipe_steps'),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recipe!.steps
                            .asMap()
                            .entries
                            .map(
                              (e) => _ChecklistTile(
                                index: e.key,
                                text: e.value,
                                checked: _checkedSteps.contains(e.key),
                                onToggle: () => _toggleStep(e.key),
                              ),
                            )
                            .toList(),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          _BottomDoneButton(
            label: strings.t('detail_button_finish'),
            recipe: recipe!,
            categoryId: categoryId,
            enabled: _isChecklistComplete,
            onCompleted: () async {
              await AppDatabase.instance.debugCheckDatabase();
              setState(() {
                _isCompleted = true;
              });
              _loadStatuses(recipe!.id);
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderImage extends StatelessWidget {
  final String imagePath;
  final VoidCallback onBack;
  final VoidCallback onFavoriteToggle;
  final bool isFavorite;

  const _HeaderImage({
    required this.imagePath,
    required this.onBack,
    required this.onFavoriteToggle,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.overlayDark,
                    Colors.transparent,
                    AppColors.overlayMedium,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPadding + 12,
            left: 16,
            child: _TopActionButton(
              icon: Icons.arrow_back,
              onTap: onBack,
            ),
          ),
          Positioned(
            top: topPadding + 12,
            right: 16,
            child: _TopActionButton(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              onTap: onFavoriteToggle,
              backgroundColor:
                  isFavorite ? AppColors.primary : AppColors.overlayDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const _TopActionButton({
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.overlayDark,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.background.withOpacity(0.4),
          ),
        ),
        child: Icon(
          icon,
          color: iconColor ?? AppColors.background,
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final int index;
  final String text;
  final bool checked;
  final VoidCallback onToggle;

  const _ChecklistTile({
    required this.index,
    required this.text,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.poppins(
      fontSize: 14,
      color: AppColors.primary.withOpacity(checked ? 0.6 : 1),
      decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
      decorationThickness: 2,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 8, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onToggle,
              child: Text(
                "${index + 1}. $text",
                style: textStyle,
              ),
            ),
          ),
          Checkbox(
            value: checked,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.primary,
            checkColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChipsRow extends StatelessWidget {
  final AppLocalizations strings;
  final RecipeModel recipe;

  const _TimeChipsRow({
    required this.strings,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (strings.t('detail_time_total'), recipe.totalTime ?? "-"),
      (strings.t('detail_time_prep'), recipe.prepTime ?? "-"),
      (strings.t('detail_time_cooking'), recipe.cookTime ?? "-"),
    ];

    return Row(
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 12),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  item.$1,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BottomDoneButton extends StatelessWidget {
  final String label;
  final RecipeModel recipe;
  final String? categoryId;
  final bool enabled;
  final Future<void> Function() onCompleted;
  const _BottomDoneButton({
    required this.label,
    required this.recipe,
    required this.categoryId,
    required this.enabled,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: enabled
              ? () async {
                  await AppDatabase.instance.markCompleted(recipe.id);
                  await onCompleted();
                  if (context.mounted) {
                    Navigator.pushNamed(context, Routes.cookingComplete);
                  }
                }
              : null,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.background,
            ),
          ),
        ),
      ),
    );
  }
}

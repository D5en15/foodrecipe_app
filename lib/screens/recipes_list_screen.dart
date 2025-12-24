import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../app_router.dart';
import '../l10n/app_localizations.dart';
import '../models/recipe_model.dart';
import '../services/recipe_service.dart';
import '../theme/app_colors.dart';
import '../services/category_service.dart';

// -----------------------------------------------------
// Recipes List Screen
// -----------------------------------------------------
class RecipesListScreen extends StatefulWidget {
  const RecipesListScreen({super.key});

  @override
  State<RecipesListScreen> createState() => _RecipesListScreenState();
}

class _TaggedRecipe {
  final RecipeModel recipe;
  final List<String> categoryNames;
  final List<String> categoryIds;
  final String cuisineName;
  final String cuisineId;

  _TaggedRecipe(
    this.recipe,
    this.categoryNames,
    this.categoryIds,
    this.cuisineName,
    this.cuisineId,
  );
}

enum _SortOption {
  random,
  alphabetical,
  timeShortest,
  timeLongest,
}

class _RecipesListScreenState extends State<RecipesListScreen> {
  List<_TaggedRecipe> recipes = [];
  List<_TaggedRecipe> filtered = [];
  final TextEditingController _searchController = TextEditingController();
  Locale _currentLocale = const Locale('th');

  String? categoryId;
  String? cuisineId;
  String? initialSearchText;
  bool _didInitArgs = false;
  Map<String, String> _categoryNames = {};
  String? _categoryNamesLang;
  Map<String, String> _cuisineNames = {};
  String? _cuisineNamesLang;
  List<_TaggedRecipe> _allRecipes = [];
  String? _allRecipesLang;
  _SortOption _sortOption = _SortOption.random;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _currentLocale =
        AppLocalizations.of(context)?.locale ?? const Locale('th');

    if (!_didInitArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;

      String? incomingSearch;

      if (args is String) {
        categoryId = args;
      } else if (args is Map) {
        if (args["category"] != null) {
          categoryId = args["category"];
        } else if (args["categoryId"] != null) {
          categoryId = args["categoryId"];
        } else if (args["id"] != null) {
          categoryId = args["id"];
        }
        if (args["cuisine"] != null) {
          cuisineId = args["cuisine"];
        } else if (args["cuisineId"] != null) {
          cuisineId = args["cuisineId"];
        }

        incomingSearch = args["search"] as String?;
      }

      final hasSpecificCategory =
          categoryId != null && categoryId!.isNotEmpty && categoryId != "all";
      final hasSpecificCuisine =
          cuisineId != null && cuisineId!.isNotEmpty && cuisineId != "all";

      if (!hasSpecificCategory &&
          !hasSpecificCuisine &&
          incomingSearch != null &&
          incomingSearch.trim().isNotEmpty) {
        initialSearchText = incomingSearch;
      } else {
        initialSearchText = null;
      }

      if (initialSearchText != null && initialSearchText!.isNotEmpty) {
        _searchController.text = initialSearchText!;
      }

      _didInitArgs = true;
    }

    loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// แปลงชื่อไฟล์ JSON → ชื่อหมวด
  /// snack_and_appetizers → Snack And Appetizers
  String fileNameToCategoryName(String file) {
    final name = file.replaceAll(".json", "").replaceAll("_", " ");
    return name
        .split(" ")
        .map((e) => "${e[0].toUpperCase()}${e.substring(1)}")
        .join(" ");
  }

  Future<void> _loadCategoryNames(String lang) async {
    if (_categoryNamesLang == lang && _categoryNames.isNotEmpty) return;

    try {
      _categoryNames = await CategoryService.loadCategoryNameMap(lang);
      _categoryNamesLang = lang;
    } catch (e) {
      print("❌ ERROR loading category names: $e");
      _categoryNames = {};
      _categoryNamesLang = null;
    }
  }

  Future<void> _loadCuisineNames(String lang) async {
    if (_cuisineNamesLang == lang && _cuisineNames.isNotEmpty) return;
    try {
      final jsonString =
          await rootBundle.loadString("assets/data/cuisines.json");
      final List<dynamic> data = json.decode(jsonString) as List<dynamic>;

      String localizedNameFor(
          Map<String, dynamic> json, String languageCode) {
        final translations =
            json['translations'] as Map<String, dynamic>? ?? const {};
        final langEntry = translations[languageCode];
        if (langEntry is Map && langEntry['name'] is String) {
          return langEntry['name'] as String;
        }
        final enEntry = translations['en'];
        if (enEntry is Map && enEntry['name'] is String) {
          return enEntry['name'] as String;
        }
        for (final entry in translations.values) {
          if (entry is Map && entry['name'] is String) {
            return entry['name'] as String;
          }
        }
        return json['name']?.toString() ?? json['id']?.toString() ?? '';
      }

      _cuisineNames = {
        for (final item in data)
          (item as Map<String, dynamic>)['id'].toString():
              localizedNameFor(item as Map<String, dynamic>, lang),
      };
      _cuisineNamesLang = lang;
    } catch (e) {
      print("Г?O ERROR loading cuisine names: $e");
      _cuisineNames = {};
      _cuisineNamesLang = null;
    }
  }

  String _displayCategoryName(String id) {
    return _categoryNames[id] ?? fileNameToCategoryName(id);
  }

  List<String> _displayCategoryNames(List<String> ids) {
    return ids
        .map(_displayCategoryName)
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String _displayCuisineName(String id) {
    return _cuisineNames[id] ?? id;
  }

  Future<void> _loadAllRecipesForSearch(String lang) async {
    if (_allRecipesLang == lang && _allRecipes.isNotEmpty) return;
    await _loadCategoryNames(lang);
    await _loadCuisineNames(lang);

    final entries = await RecipeService.loadAllRecipeEntries(lang);
    _allRecipes = entries.map((entry) {
      final categoryNames = _displayCategoryNames(entry.categoryIds);
      final cuisineName = _displayCuisineName(entry.cuisineId);
      return _TaggedRecipe(
        entry.recipe,
        categoryNames,
        entry.categoryIds,
        cuisineName,
        entry.cuisineId,
      );
    }).toList();
    _allRecipesLang = lang;
  }

  Future<void> loadRecipes() async {
    final lang = _currentLocale.languageCode;

    try {
      await _loadCategoryNames(lang);
      await _loadCuisineNames(lang);

      List<_TaggedRecipe> loaded = [];

      final hasSpecificCategory =
          categoryId != null && categoryId!.isNotEmpty && categoryId != "all";
      final hasSpecificCuisine =
          cuisineId != null && cuisineId!.isNotEmpty && cuisineId != "all";

      if (!hasSpecificCategory && !hasSpecificCuisine) {
        final all = await RecipeService.loadAllRecipesWithCategories(lang);

        loaded = all.map((entry) {
          final catId = entry["categoryId"] as String;
          final cuisineId = entry["cuisineId"] as String? ?? '';
          final recipe = entry["recipe"] as RecipeModel;
          final cuisineName = _displayCuisineName(cuisineId);
          final categoryNames = _displayCategoryNames([catId]);
          return _TaggedRecipe(
            recipe,
            categoryNames,
            [catId],
            cuisineName,
            cuisineId,
          );
        }).toList();
      } else {
        final entries = await RecipeService.loadAllRecipeEntries(lang);
        loaded = entries
            .where((entry) {
              final matchesCategory = hasSpecificCategory
                  ? entry.categoryIds.contains(categoryId!)
                  : true;
              final matchesCuisine =
                  hasSpecificCuisine ? entry.cuisineId == cuisineId : true;
              return matchesCategory && matchesCuisine;
            })
            .map((entry) {
              final categoryIds =
                  entry.categoryIds.isNotEmpty ? entry.categoryIds : <String>[];
              final categoryNames = _displayCategoryNames(categoryIds);
              final cuisineName = _displayCuisineName(entry.cuisineId);
              return _TaggedRecipe(
                entry.recipe,
                categoryNames,
                categoryIds,
                cuisineName,
                entry.cuisineId,
              );
            })
            .toList();
      }

      if (loaded.isEmpty) {
        loaded = await _loadFallbackRecipes(lang);
      }

      if (_sortOption == _SortOption.random) {
        loaded.shuffle();
      }

      final effectiveInitial = initialSearchText?.trim();

      final shouldApplyInitial =
          effectiveInitial != null && effectiveInitial.isNotEmpty;
      final lowerInitial = effectiveInitial?.toLowerCase();
      final List<_TaggedRecipe> initialFiltered = shouldApplyInitial
          ? loaded.where((item) => _matchesQuery(item, lowerInitial!)).toList()
          : loaded;

      setState(() {
        recipes = loaded;
        filtered = _sortRecipes(initialFiltered);
        if (shouldApplyInitial) {
          _searchController.text = effectiveInitial!;
        }
      });
    } catch (e) {
      print("❌ ERROR loading recipes: $e");
    }
  }

  Future<List<_TaggedRecipe>> _loadFallbackRecipes(String lang) async {
    final entries = await RecipeService.loadAllRecipeEntries(lang);
    if (entries.isEmpty) return [];
    entries.shuffle();
    final sliced = entries.take(10).toList();
    return sliced.map((entry) {
      final catId =
          entry.categoryIds.isNotEmpty ? entry.categoryIds.first : 'maincourse';
      final categoryNames = _displayCategoryNames([catId]);
      final cuisineName = _displayCuisineName(entry.cuisineId);
      return _TaggedRecipe(
        entry.recipe,
        categoryNames,
        [catId],
        cuisineName,
        entry.cuisineId,
      );
    }).toList();
  }

  // -----------------------------------------------------
  // Search Function
  // -----------------------------------------------------
  void filterRecipes(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        filtered = _sortRecipes(recipes);
      });
      return;
    }

    final q = trimmed.toLowerCase();

    await _loadAllRecipesForSearch(_currentLocale.languageCode);
    final searchBase = _allRecipes.isNotEmpty ? _allRecipes : recipes;

    setState(() {
      filtered =
          _sortRecipes(searchBase.where((item) => _matchesQuery(item, q)).toList());
    });
  }

  bool _matchesQuery(_TaggedRecipe item, String q) {
    final titleMatch =
        item.recipe.displayTitle(_currentLocale).toLowerCase().contains(q);
    final categoryMatch =
        item.categoryNames.any((name) => name.toLowerCase().contains(q));
    final ingredientMatch = item.recipe.ingredients
        .any((ingredient) => ingredient.toLowerCase().contains(q));
    return titleMatch || categoryMatch || ingredientMatch;
  }

  List<_TaggedRecipe> _sortRecipes(List<_TaggedRecipe> items) {
    if (_sortOption == _SortOption.random) {
      return List<_TaggedRecipe>.from(items);
    }
    final sorted = List<_TaggedRecipe>.from(items);
    switch (_sortOption) {
      case _SortOption.alphabetical:
        sorted.sort(_compareAlphabetical);
        break;
      case _SortOption.timeShortest:
        sorted.sort(_compareTotalTime);
        break;
      case _SortOption.timeLongest:
        sorted.sort((a, b) => _compareTotalTime(b, a));
        break;
      case _SortOption.random:
        break;
    }
    return sorted;
  }

  int _compareAlphabetical(_TaggedRecipe a, _TaggedRecipe b) {
    final aTitle = a.recipe.displayTitle(_currentLocale).toLowerCase();
    final bTitle = b.recipe.displayTitle(_currentLocale).toLowerCase();
    final result = aTitle.compareTo(bTitle);
    if (result != 0) return result;
    return a.recipe.id.compareTo(b.recipe.id);
  }

  int _compareTotalTime(_TaggedRecipe a, _TaggedRecipe b) {
    final aTime = _totalMinutes(a.recipe.totalTime);
    final bTime = _totalMinutes(b.recipe.totalTime);
    final diff = aTime - bTime;
    if (diff != 0) return diff;
    return _compareAlphabetical(a, b);
  }

  int _totalMinutes(String? raw) {
    if (raw == null) return 0;
    final lower = raw.toLowerCase();
    int minutes = 0;

    int? _matchNumber(RegExp regex, String source) {
      final match = regex.firstMatch(source);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '');
      }
      return null;
    }

    final hourPatterns = [
      RegExp(r'(\d+)\s*(?:hours?|hrs?|hr)', caseSensitive: false),
    ];
    for (final pattern in hourPatterns) {
      final value = _matchNumber(pattern, lower);
      if (value != null) {
        minutes += value * 60;
        break;
      }
    }
    final thaiHour = _matchNumber(RegExp(r'(\d+)\s*ชั่วโมง'), raw);
    if (thaiHour != null) {
      minutes += thaiHour * 60;
    }

    final minutePatterns = [
      RegExp(r'(\d+)\s*(?:minutes?|mins?|min)', caseSensitive: false),
    ];
    for (final pattern in minutePatterns) {
      final value = _matchNumber(pattern, lower);
      if (value != null) {
        minutes += value;
        break;
      }
    }
    final thaiMinute = _matchNumber(RegExp(r'(\d+)\s*นาที'), raw);
    if (thaiMinute != null) {
      minutes += thaiMinute;
    }

    if (minutes == 0) {
      final fallback = _matchNumber(RegExp(r'(\d+)'), raw);
      if (fallback != null) {
        minutes = fallback;
      }
    }

    return minutes;
  }

  Future<void> _openSortSheet() async {
    final strings = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<_SortOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortBottomSheet(
        strings: strings,
        current: _sortOption,
      ),
    );

    if (selected != null && selected != _sortOption) {
      setState(() {
        _sortOption = selected;
      });
      filterRecipes(_searchController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _HeaderSection(
            strings: strings,
            onSearch: filterRecipes,
            controller: _searchController,
            onFilterTap: _openSortSheet,
            onBackTap: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                Routes.home,
                (route) => false,
              );
            },
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      "ไม่พบเมนู",
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      color: AppColors.accent.withOpacity(0.2),
                      height: 30,
                    ),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final displayTitle =
                          item.recipe.displayTitle(_currentLocale);
                      return _RecipeListItem(
                        imagePath: item.recipe.image,
                        title: displayTitle,
                        subtitle: "Recipe",
                        tags: _buildTags(item),
                        timeText:
                            "${strings.t('detail_time_total')} : ${item.recipe.totalTime ?? '-'}",
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            Routes.recipeDetail,
                            arguments: {
                              "id": item.recipe.id,
                              "category": item.categoryIds.isNotEmpty
                                  ? item.categoryIds.first
                                  : null,
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

List<String> _buildTags(_TaggedRecipe item) {
  final tags = <String>[];
  final cuisine = item.cuisineName.trim();
  if (cuisine.isNotEmpty) {
    tags.add(cuisine);
  }
  for (final category in item.categoryNames) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.toLowerCase() == cuisine.toLowerCase()) continue;
    if (!tags.any((tag) => tag.toLowerCase() == trimmed.toLowerCase())) {
      tags.add(trimmed);
    }
  }
  return tags;
}

// -----------------------------------------------------
// Header Section (Search Bar + Tabs)
// -----------------------------------------------------
class _HeaderSection extends StatelessWidget {
  final AppLocalizations strings;
  final Function(String) onSearch;
  final TextEditingController controller;
  final VoidCallback onFilterTap;
  final VoidCallback onBackTap;

  const _HeaderSection({
    required this.strings,
    required this.onSearch,
    required this.controller,
    required this.onFilterTap,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⭐ Search Bar (แก้ให้อยู่ตรงกลางจริง)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onBackTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),

                        Expanded(
                          child: TextField(
                            controller: controller,
                            onChanged: onSearch,
                            maxLines: 1,
                            textAlignVertical: TextAlignVertical.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              border: InputBorder.none,
                              hintText: strings.t('home_search_hint'),
                              hintStyle: GoogleFonts.poppins(
                                color: AppColors.primary.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        InkWell(
                          onTap: () => onSearch(controller.text.trim()),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.search,
                                color: AppColors.background, size: 20),
                          ),
                        ),

                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onFilterTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child:
                        _TabItem(label: strings.t('list_tab_all'), isActive: true),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _TabItem(
                        label: strings.t('list_tab_recipes'), isActive: false),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _TabItem(
                        label: strings.t('list_tab_users'), isActive: false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------
// Tab Widget
// -----------------------------------------------------
class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  const _TabItem({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.background,
            fontSize: 16,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 4,
          width: 60,
          decoration: BoxDecoration(
            color: isActive ? AppColors.background : Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------
// Recipe List Item
// -----------------------------------------------------
class _RecipeListItem extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final List<String> tags;
  final String timeText;
  final VoidCallback onTap;

  const _RecipeListItem({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.timeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          // Image
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.overlayLight,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: ClipOval(
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),

          const SizedBox(width: 16),

          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: AppColors.primary.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 8),

                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.poppins(
                            color: AppColors.background,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 8),

                Text(
                  timeText,
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortBottomSheet extends StatelessWidget {
  final AppLocalizations strings;
  final _SortOption current;

  const _SortBottomSheet({
    required this.strings,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SortOption.random,
      _SortOption.alphabetical,
      _SortOption.timeShortest,
      _SortOption.timeLongest,
    ];

    String _labelFor(_SortOption option) {
      switch (option) {
        case _SortOption.random:
          return strings.t('filter_option_recommended');
        case _SortOption.alphabetical:
          return strings.t('filter_option_alphabetical');
        case _SortOption.timeShortest:
          return strings.t('filter_option_time_short');
        case _SortOption.timeLongest:
          return strings.t('filter_option_time_long');
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              strings.t('filter_sort_title'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.t('filter_sort_description'),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (option) => RadioListTile<_SortOption>(
                value: option,
                groupValue: current,
                onChanged: (value) {
                  Navigator.of(context).pop(value);
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.primary,
                title: Text(
                  _labelFor(option),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.primary,
                    fontWeight: current == option
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

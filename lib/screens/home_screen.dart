import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_router.dart';
import '../l10n/app_localizations.dart';
import '../services/recipe_service.dart';
import '../models/recipe_model.dart';
import '../theme/app_colors.dart';
import '../database/app_database.dart';
import '../services/category_service.dart';
import '../models/category_model.dart';

// ----------------------
// Category Model
// ----------------------
class CategoryItem {
  final String id;
  final String name;
  final String image;

  CategoryItem({
    required this.id,
    required this.name,
    required this.image,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'],
      name: json['name'],
      image: json['image'],
    );
  }
}

// ----------------------
// HomeScreen
// ----------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CategoryItem> categories = [];
  List<_HomeRecipeCardData> _favoriteCards = [];
  List<_HomeRecipeCardData> _popularCards = [];
  List<_HomeRecipeCardData> _completedCards = [];
  String? _currentLang;
  Set<String> _favoriteIds = {};
  Set<String> _completedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppDatabase.instance.debugCheckDatabase();
      loadCategories();
      _loadFavoriteCards();
      _loadPopularCards();
      _loadCompletedCards();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang =
        AppLocalizations.of(context)?.locale.languageCode ?? _currentLang;
    if (lang != null && lang != _currentLang) {
      _currentLang = lang;
      loadCategories(localeOverride: Locale(lang));
      _loadFavoriteCards(localeCode: lang);
      _loadPopularCards(localeCode: lang);
      _loadCompletedCards(localeCode: lang);
    }
  }

  Future<void> loadCategories({Locale? localeOverride}) async {
    final lang =
        (localeOverride ?? context.read<AppLanguage>().appLocale).languageCode;

    try {
      final List<CategoryModel> models =
          await CategoryService.loadCategories(lang);

      List<CategoryItem> loaded = models
          .map((model) => CategoryItem(
                id: model.id,
                name: model.name,
                image: model.image,
              ))
          .toList();

      loaded.shuffle();
      loaded = loaded.take(4).toList();

      setState(() => categories = loaded);
    } catch (e) {
      print("ERROR loading categories: $e");
    }
  }

  void _handleLanguageChange(Locale locale) {
    final appLang = context.read<AppLanguage>();
    if (appLang.appLocale == locale) return;
    appLang.changeLanguage(locale);
    loadCategories(localeOverride: locale);
    _loadFavoriteCards(localeCode: locale.languageCode);
    _loadPopularCards(localeCode: locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final appLang = Provider.of<AppLanguage>(context);
    final lang = appLang.appLocale.languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _RecipeSliverAppBar(
            strings: strings,
            currentLocale: appLang.appLocale,
            onChangeLanguage: _handleLanguageChange,
          ),

          // CONTENT
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _CategorySection(
                  strings: strings,
                  categories: categories,
                ),
              ),

              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                color: AppColors.accent.withOpacity(0.5),
                padding: const EdgeInsets.only(
                    top: 20, bottom: 40, left: 20, right: 20),
                child: Column(
                  children: [
                    _SectionTitle(
                      title: strings.t('home_section_popular'),
                      showAllText: strings.t('home_button_view_all_categories'),
                      onTapShowAll: () => Navigator.pushNamed(
                        context,
                        Routes.recipes,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_popularCards.isEmpty)
                      const SizedBox(height: 170)
                    else
                      _HorizontalCards(
                        items: _popularCards,
                        height: 170,
                        cardWidth: 143,
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  children: [
                    _SectionTitle(
                      title: strings.t('home_section_favorites'),
                      showAllText: strings.t('home_button_view_all_categories'),
                      onTapShowAll: () =>
                          Navigator.pushNamed(context, Routes.favorites),
                    ),
                    const SizedBox(height: 12),
                    if (_favoriteCards.isNotEmpty)
                      _HorizontalCards(
                        items: _favoriteCards,
                        height: 170,
                        cardWidth: 143,
                      ),
                    if (_favoriteCards.isEmpty)
                      SizedBox(
                        height: 170,
                        child: Center(
                          child: Text(
                            strings.t('empty_state_title'),
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              Container(
                color: AppColors.accent.withOpacity(0.5),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: _CompletedSection(
                  strings: strings,
                  items: _completedCards,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFavoriteCards({String? localeCode}) async {
    final favIds = await AppDatabase.instance.getFavoriteIds();
    final lang =
        localeCode ?? AppLocalizations.of(context)?.locale.languageCode ?? "th";
    final locale = Locale(lang);

    _currentLang = lang;
    _favoriteIds = favIds;

    if (favIds.isEmpty) {
      setState(() => _favoriteCards = []);
      return;
    }

    try {
      final entries = await RecipeService.loadAllRecipeEntries(lang);
      final lookup = {
        for (final entry in entries) entry.recipe.id: entry,
      };
      final List<_HomeRecipeCardData> cards = [];
      for (final favId in favIds) {
        final entry = lookup[favId];
        if (entry == null) continue;
        final catId =
            entry.categoryIds.isNotEmpty ? entry.categoryIds.first : 'maincourse';
        cards.add(_HomeRecipeCardData(
          id: entry.recipe.id,
          title: entry.recipe.displayTitle(locale),
          image: entry.recipe.image,
          categoryId: catId,
        ));
      }

      if (!mounted) return;
      setState(() {
        _favoriteCards = cards.take(5).toList();
      });
    } catch (e) {
      print("❌ ERROR loading favorites for home: $e");
    }
  }

  Future<void> _loadPopularCards({String? localeCode}) async {
    final lang =
        localeCode ?? AppLocalizations.of(context)?.locale.languageCode ?? "th";
    final locale = Locale(lang);

    try {
      final samples = await RecipeService.loadSampleEntries(
        languageCode: lang,
        count: 10,
      );
      final cards = samples.map((entry) {
        final catId = entry.categoryIds.isNotEmpty
            ? entry.categoryIds.first
            : 'maincourse';
        return _HomeRecipeCardData(
          id: entry.recipe.id,
          title: entry.recipe.displayTitle(locale),
          image: entry.recipe.image,
          categoryId: catId,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _popularCards = cards;
      });
    } catch (e) {
      print("❌ ERROR loading popular for home: $e");
      if (!mounted) return;
      setState(() {
        _popularCards = [];
      });
    }
  }

  Future<void> _loadCompletedCards({String? localeCode}) async {
    final compIds = await AppDatabase.instance.getCompletedIds();
    final lang =
        localeCode ?? AppLocalizations.of(context)?.locale.languageCode ?? "th";
    final locale = Locale(lang);
    _completedIds = compIds;

    if (compIds.isEmpty) {
      setState(() {
        _completedCards = [];
      });
      return;
    }

    try {
      final entries = await RecipeService.loadAllRecipeEntries(lang);
      final lookup = {
        for (final entry in entries) entry.recipe.id: entry,
      };
      final List<_HomeRecipeCardData> cards = [];
      for (final compId in compIds) {
        final entry = lookup[compId];
        if (entry == null) continue;
        final catId =
            entry.categoryIds.isNotEmpty ? entry.categoryIds.first : 'maincourse';
        cards.add(_HomeRecipeCardData(
          id: entry.recipe.id,
          title: entry.recipe.displayTitle(locale),
          image: entry.recipe.image,
          categoryId: catId,
        ));
      }

      if (!mounted) return;
      setState(() {
        _completedCards = cards.take(5).toList();
      });
    } catch (e) {
      print("❌ ERROR loading completed for home: $e");
    }
  }
}

// ----------------------
// App Bar
// ----------------------
class _RecipeSliverAppBar extends StatelessWidget {
  final AppLocalizations strings;
  final Locale currentLocale;
  final ValueChanged<Locale> onChangeLanguage;

  const _RecipeSliverAppBar({
    required this.strings,
    required this.currentLocale,
    required this.onChangeLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      expandedHeight: 290,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/hero_food.jpg', fit: BoxFit.cover),
            Container(color: AppColors.overlayMedium),

            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              left: 20,
              child: _LanguageSelector(
                currentLocale: currentLocale,
                onSelected: onChangeLanguage,
                strings: strings,
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              bottom: 85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.t('home_hero_title'),
                      style: GoogleFonts.poppins(
                        color: AppColors.background,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      )),
                  Text(strings.t('home_hero_count'),
                      style: GoogleFonts.poppins(
                        color: AppColors.background,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 6),
                  Text(strings.t('home_hero_subtitle'),
                      style: GoogleFonts.poppins(
                        color: AppColors.background.withOpacity(0.9),
                        fontSize: 15,
                      )),
                ],
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: _SearchBar(strings: strings),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------
// Language Selector
// ----------------------
class _LanguageSelector extends StatelessWidget {
  final Locale currentLocale;
  final ValueChanged<Locale> onSelected;
  final AppLocalizations strings;

  const _LanguageSelector({
    required this.currentLocale,
    required this.onSelected,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final currentCode = currentLocale.languageCode;
    final displayCode = currentCode == 'th' ? 'TH' : 'EN';

    PopupMenuItem<Locale> buildItem({
      required Locale locale,
      required String code,
      required String label,
    }) {
      final isActive = currentCode == locale.languageCode;
      return PopupMenuItem<Locale>(
        value: locale,
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  isActive ? AppColors.primary : AppColors.background,
              child: Text(
                code,
                style: GoogleFonts.poppins(
                  color: isActive ? AppColors.background : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: AppColors.background,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<Locale>(
      onSelected: onSelected,
      offset: const Offset(0, 8),
      color: AppColors.overlayDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        buildItem(
          locale: const Locale('th'),
          code: 'TH',
          label: strings.t('language_th'),
        ),
        buildItem(
          locale: const Locale('en'),
          code: 'EN',
          label: strings.t('language_en'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.background,
              child: Text(
                displayCode,
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down,
                color: AppColors.background),
          ],
        ),
      ),
    );
  }
}

// ----------------------
// Search Bar + Discover
// ----------------------
class _SearchBar extends StatefulWidget {
  final AppLocalizations strings;

  const _SearchBar({required this.strings});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _controller.text.trim();
    Navigator.pushNamed(
      context,
      Routes.recipes,
      arguments: {"search": query},
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return Row(
      children: [
        // SEARCH BAR
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
                    controller: _controller,
                    maxLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                      hintText: strings.t('home_search_hint'),
                      border: InputBorder.none,
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.primary.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                    onSubmitted: (_) => _submitSearch(),
                  ),
                ),
                InkWell(
                  onTap: _submitSearch,
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
      ],
    );
  }
}

// ----------------------
// Categories Section
// ----------------------
class _CategorySection extends StatelessWidget {
  final AppLocalizations strings;
  final List<CategoryItem> categories;

  const _CategorySection({
    required this.strings,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.of(context).size.width - 70) / 4;

    return Column(
      children: [
        _SectionTitle(
          title: strings.t('home_section_categories'),
          showAllText: strings.t('home_button_view_all_categories'),
          onTapShowAll: () =>
              Navigator.pushNamed(context, Routes.categories),
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: size,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final item = categories[index];
              return _CategoryCard(
                name: item.name,
                imagePath: item.image,
                isLast: index == categories.length - 1,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    Routes.recipes,
                    arguments: {
                      "category": item.id,
                      "categoryName": item.name,
                      "search": item.name,
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ----------------------
// Category Card
// ----------------------
class _CategoryCard extends StatelessWidget {
  final String name;
  final String imagePath;
  final bool isLast;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.name,
    required this.imagePath,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.of(context).size.width - 70) / 4;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.only(right: isLast ? 0 : 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
              Container(color: AppColors.overlayMedium),
              Center(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: AppColors.background,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------
// Completed Section
// ----------------------
class _CompletedSection extends StatelessWidget {
  final AppLocalizations strings;
  final List<_HomeRecipeCardData> items;

  const _CompletedSection({
    required this.strings,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: _SectionTitle(
            title: strings.t('home_section_completed'),
            showAllText: strings.t('home_button_view_all_categories'),
            onTapShowAll: () => Navigator.pushNamed(
              context,
              Routes.finishCook,
            ),
            showTrailing: items.isNotEmpty,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          SizedBox(
            height: 170,
            child: Center(
              child: Text(
                strings.t('empty_state_title'),
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          _HorizontalCards(
            items: items.take(5).toList(),
            height: 170,
            cardWidth: 143,
          ),
      ],
    );
  }
}

// ----------------------
// Section Title
// ----------------------
class _SectionTitle extends StatelessWidget {
  final String title;
  final String showAllText;
  final VoidCallback onTapShowAll;
  final bool showTrailing;

  const _SectionTitle({
    required this.title,
    required this.showAllText,
    required this.onTapShowAll,
    this.showTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        if (showTrailing)
          GestureDetector(
            onTap: onTapShowAll,
            child: Text(
              showAllText,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _HorizontalCards extends StatelessWidget {
  final List<_HomeRecipeCardData> items;
  final double height;
  final double cardWidth;

  const _HorizontalCards({
    required this.items,
    required this.height,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
              child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 20),
        itemBuilder: (context, index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                Routes.recipeDetail,
                arguments: {
                  "id": item.id,
                  "category": item.categoryId,
                },
              ).then((_) {
                if (context.mounted) {
                  _HomeScreenState? state =
                      context.findAncestorStateOfType<_HomeScreenState>();
                  state?._loadFavoriteCards();
                  state?._loadCompletedCards();
                }
              });
            },
            child: Container(
              width: cardWidth,
              height: height,
              margin: EdgeInsets.only(right: isLast ? 0 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.overlayLight,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      item.image,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.overlayLight,
                            AppColors.overlayDark,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: AppColors.background,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 0),
        itemCount: items.length,
      ),
    );
  }
}

class _HomeRecipeCardData {
  final String id;
  final String title;
  final String image;
  final String? categoryId;

  _HomeRecipeCardData({
    required this.id,
    required this.title,
    required this.image,
    required this.categoryId,
  });
}

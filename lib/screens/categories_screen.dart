import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../app_router.dart';
import '../theme/app_colors.dart';

// =============================
// CATEGORY MODEL
// =============================
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

// =============================
// SCREEN
// =============================
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<CategoryItem> categories = [];
  late String _currentLang;

  @override
  void initState() {
    super.initState();

    // ⭐ โหลดหลังจาก UI + Localization พร้อมแล้ว
    _currentLang =
        Provider.of<AppLanguage>(context, listen: false).appLocale.languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCategories();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang =
        Provider.of<AppLanguage>(context).appLocale.languageCode;
    if (lang != _currentLang) {
      _currentLang = lang;
      loadCategories();
    }
  }

  Future<void> loadCategories() async {
    final lang = _currentLang;

    print("=== LOAD ALL CATEGORIES ===");
    print("LANG = $lang");

    try {
      final jsonString =
          await rootBundle.loadString('assets/data/categories_$lang.json');

      final List data = json.decode(jsonString);

      print("CATEGORY COUNT = ${data.length}");
      print("CATEGORY RAW = $data");

      setState(() {
        categories = data.map((e) => CategoryItem.fromJson(e)).toList();
      });
    } catch (e) {
      print("ERROR LOADING categories: $e");
    }

    print("=== END LOAD CATEGORIES ===");
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
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: Center(
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.background, size: 24),
            ),
          ),
        ),
        title: Text(
          strings.t('category_page_title'),
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),

      // ==========================
      // GRID VIEW
      // ==========================
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final item = categories[index];
            return _CategoryGridItem(
              name: item.name,
              imagePath: item.image,
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
    );
  }
}

// =============================
// CATEGORY CARD
// =============================
class _CategoryGridItem extends StatelessWidget {
  final String name;
  final String imagePath;
  final VoidCallback onTap;

  const _CategoryGridItem({
    required this.name,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.overlayLight,
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ⭐ รูปแสดงเต็มช่อง ไม่ยืดแตก
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  print("IMAGE NOT FOUND: $imagePath");
                  return Container(
                    color: AppColors.background,
                    child: const Icon(Icons.broken_image,
                        size: 40, color: AppColors.primary),
                  );
                },
              ),

              // black overlay
              Container(color: AppColors.overlayMedium),

              // text
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.background,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
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

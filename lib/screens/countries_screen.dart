import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../app_router.dart';
import '../theme/app_colors.dart';

class CountryItem {
  final String id;
  final String name;
  final String image;

  CountryItem({
    required this.id,
    required this.name,
    required this.image,
  });
}

class CountriesScreen extends StatefulWidget {
  const CountriesScreen({super.key});

  @override
  State<CountriesScreen> createState() => _CountriesScreenState();
}

class _CountriesScreenState extends State<CountriesScreen> {
  List<CountryItem> countries = [];
  late String _currentLang;

  @override
  void initState() {
    super.initState();
    _currentLang =
        Provider.of<AppLanguage>(context, listen: false).appLocale.languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCountries();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Provider.of<AppLanguage>(context).appLocale.languageCode;
    if (lang != _currentLang) {
      _currentLang = lang;
      loadCountries();
    }
  }

  Future<void> loadCountries() async {
    final lang = _currentLang;

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

      setState(() {
        countries = data
            .map((item) => item as Map<String, dynamic>)
            .map(
              (item) => CountryItem(
                id: item['id'].toString(),
                name: localizedNameFor(item, lang),
                image: item['image']?.toString() ?? '',
              ),
            )
            .toList();
      });
    } catch (e) {
      print("ERROR LOADING countries: $e");
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
          strings.t('country_page_title'),
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: countries.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final item = countries[index];
            return _CountryGridItem(
              name: item.name,
              imagePath: item.image,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  Routes.recipes,
                  arguments: {
                    "cuisine": item.id,
                    "cuisineName": item.name,
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

class _CountryGridItem extends StatelessWidget {
  final String name;
  final String imagePath;
  final VoidCallback onTap;

  const _CountryGridItem({
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
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: AppColors.background,
                    child: const Icon(Icons.flag,
                        size: 40, color: AppColors.primary),
                  );
                },
              ),
              Container(color: AppColors.overlayMedium),
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

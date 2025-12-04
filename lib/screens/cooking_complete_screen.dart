import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_router.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

class CookingCompleteScreen extends StatelessWidget {
  const CookingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),

              // เปลี่ยนภาษาได้
              Text(
                strings.t('completion_title'),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                strings.t('completion_message'),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),

              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      Routes.home,
                      (route) => false,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      strings.t('completion_button_done'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.background,
                      ),
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

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'l10n/app_localizations.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppLanguage()),
      ],
      child: const FoodRecipeApp(),
    ),
  );
}

class FoodRecipeApp extends StatelessWidget {
  const FoodRecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appLanguage = Provider.of<AppLanguage>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.t('app_name') ?? 'CookEasy',

      theme: AppTheme.light,

      locale: appLanguage.appLocale,
      supportedLocales: const [
        Locale('en', ''),
        Locale('th', ''),
      ],

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      initialRoute: Routes.welcome,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

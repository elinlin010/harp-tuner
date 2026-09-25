import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'screens/tuner_screen.dart';
import 'services/feedback_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  // Attempt Firebase init for in-app feedback. Non-fatal: if no Firebase
  // project is configured yet (run `flutterfire configure`), feedback is
  // silently disabled and the rest of the app runs normally.
  await FeedbackService.instance.tryInitialize();
  // Resolve the theme before the first frame so the app opens on it directly
  // (new installs default to Maple, existing installs keep Linen). The native
  // splash covers the wait; the timeout keeps a stuck platform call from
  // holding the app on it.
  final startupTheme = await resolveStartupTheme()
      .timeout(const Duration(seconds: 2))
      .then<TunerThemeData?>((t) => t, onError: (Object e) {
    debugPrint('main: startup theme unresolved, loading async: $e');
    return null;
  });
  runApp(ProviderScope(
    overrides: [startupThemeProvider.overrideWithValue(startupTheme)],
    child: const HarpTunerApp(),
  ));
}

class HarpTunerApp extends ConsumerWidget {
  const HarpTunerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final tunerTheme = ref.watch(tunerThemeProvider);
    final isDark = tunerTheme.brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
    return MaterialApp(
      title: 'Harpie',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      // Clamp system font scale: respect user's accessibility setting up to
      // 1.3× but prevent layout overflow at extreme scales.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
      home: const TunerScreen(),
    );
  }
}

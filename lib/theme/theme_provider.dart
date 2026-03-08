import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

/// Active theme for the tuner UI.
/// Switch themes: `ref.read(tunerThemeProvider.notifier).state = TunerThemes.blueprint`
final tunerThemeProvider = StateProvider<TunerThemeData>(
  (ref) => TunerThemes.linen,
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/l10n/app_localizations.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
import 'package:harp_tuner/widgets/settings_display.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness({ValueChanged<SettingsSection>? onTap}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SettingsDisplay(onTap: onTap ?? (_) {}),
      ),
    ),
  );
}

ProviderContainer _containerFrom(WidgetTester tester) {
  final element = tester.element(find.byType(SettingsDisplay));
  return ProviderScope.containerOf(element);
}

void main() {
  group('SettingsDisplay card visibility', () {
    testWidgets('shows 3 cards when lever harp selected', (tester) async {
      SharedPreferences.setMockInitialValues({
        'tuner_harp_type': 'leverHarp',
        'tuner_lever_string_count': 34,
        'tuner_a4_hz': 440,
      });

      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(find.text('HARP'), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('STRINGS'), findsOneWidget);
      expect(find.text('Lever'), findsOneWidget);
      expect(find.text('34'), findsOneWidget);
      expect(find.text('440 Hz'), findsOneWidget);
    });

    testWidgets('hides STRINGS card when pedal harp selected', (tester) async {
      SharedPreferences.setMockInitialValues({
        'tuner_harp_type': 'pedalHarp',
        'tuner_a4_hz': 440,
      });

      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(find.text('HARP'), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
      expect(find.text('STRINGS'), findsNothing);
      expect(find.text('Pedal'), findsOneWidget);
    });

    testWidgets('shows None when no harp selected', (tester) async {
      SharedPreferences.setMockInitialValues({
        'tuner_harp_type': 'leverHarp',
        'tuner_a4_hz': 440,
      });

      await tester.pumpWidget(_harness());
      await tester.pump();

      // Clear the harp selection via the real notifier.
      await _containerFrom(tester)
          .read(tunerProvider.notifier)
          .setSelectedHarp(null);
      await tester.pump();

      expect(find.text('None'), findsOneWidget);
      expect(find.text('STRINGS'), findsNothing);
      expect(find.text('HARP'), findsOneWidget);
      expect(find.text('A4'), findsOneWidget);
    });
  });

  group('SettingsDisplay dynamic values', () {
    testWidgets('A4 card reflects custom calibration', (tester) async {
      SharedPreferences.setMockInitialValues({
        'tuner_harp_type': 'pedalHarp',
        'tuner_a4_hz': 442,
      });

      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(find.text('442 Hz'), findsOneWidget);
    });

    testWidgets('STRINGS card reflects lever string count', (tester) async {
      SharedPreferences.setMockInitialValues({
        'tuner_harp_type': 'leverHarp',
        'tuner_lever_string_count': 26,
      });

      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(find.text('26'), findsOneWidget);
    });
  });

  group('SettingsDisplay tap behavior', () {
    testWidgets('tapping instrument card fires callback with instrument section',
        (tester) async {
      SharedPreferences.setMockInitialValues({'tuner_harp_type': 'leverHarp'});
      SettingsSection? tapped;

      await tester.pumpWidget(_harness(onTap: (s) => tapped = s));
      await tester.pump();

      await tester.tap(find.text('Lever'));
      expect(tapped, SettingsSection.instrument);
    });

    testWidgets('tapping A4 card fires callback with a4 section',
        (tester) async {
      SharedPreferences.setMockInitialValues({'tuner_harp_type': 'leverHarp'});
      SettingsSection? tapped;

      await tester.pumpWidget(_harness(onTap: (s) => tapped = s));
      await tester.pump();

      await tester.tap(find.text('440 Hz'));
      expect(tapped, SettingsSection.a4);
    });

    testWidgets('tapping strings card fires callback with stringCount section',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'tuner_harp_type': 'leverHarp',
        'tuner_lever_string_count': 34,
      });
      SettingsSection? tapped;

      await tester.pumpWidget(_harness(onTap: (s) => tapped = s));
      await tester.pump();

      await tester.tap(find.text('34'));
      expect(tapped, SettingsSection.stringCount);
    });
  });
}

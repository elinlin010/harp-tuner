import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harp_tuner/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HarpTunerApp()));
    // pump one frame — pumpAndSettle hangs with repeating animations
    await tester.pump();
    expect(find.text('Start Tuning'), findsOneWidget);
  });
}

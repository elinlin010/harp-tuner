import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:harp_tuner/main.dart' as app;

void main() {
  testWidgets('main() initializes and renders HarpTunerApp without error',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    app.main();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

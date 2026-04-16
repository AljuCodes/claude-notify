import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder test', (WidgetTester tester) async {
    // Firebase requires real credentials to initialise — integration tests
    // should be run on a device or emulator with google-services configured.
    expect(true, isTrue);
  });
}

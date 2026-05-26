import 'package:flutter_test/flutter_test.dart';
import 'package:yet_another_pomodoro/main.dart';

void main() {
  testWidgets('App smoke test - verifies title displays', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that mode switcher title displays.
    expect(find.text('Classic'), findsOneWidget);
  });
}

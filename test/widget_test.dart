// Basic widget test for Daily Games app.

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_games/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyGamesApp());

    // Verify the app renders with the title
    expect(find.text('Daily Run'), findsOneWidget);
  });
}

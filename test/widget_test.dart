import 'package:flutter_test/flutter_test.dart';
import 'package:edgescribe/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EdgeScribeApp());

    // Verify the app loads (will show loading dictionaries state initially)
    expect(find.text('Loading Dictionaries...'), findsOneWidget);
  });
}

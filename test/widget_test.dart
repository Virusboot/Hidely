import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidely_new/main.dart';

void main() {
  testWidgets('HidelyApp initializes successfully', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: HidelyApp(),
      ),
    );

    // Advance fake timer in splash screen to complete initialization
    await tester.pump(const Duration(seconds: 5));

    // Verify HidelyApp builds without throwing exceptions
    expect(find.byType(HidelyApp), findsOneWidget);
  });
}

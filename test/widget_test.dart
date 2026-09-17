import 'package:flutter_test/flutter_test.dart';
import 'package:rivals/main.dart';
import 'package:rivals/screens/home_screen.dart';
import 'package:rivals/widgets/bottom_nav.dart';

void main() {
  testWidgets('App root smoke test', (WidgetTester tester) async {
    // Build RootApp and trigger a frame.
    await tester.pumpWidget(const RootApp());

    // Verify that HomeScreen and BottomNav are rendered
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(BottomNav), findsOneWidget);
  });
}

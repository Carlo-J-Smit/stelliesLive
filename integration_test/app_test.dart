import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stellieslive/main.dart' as app;
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Admin login → create event → logout", (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    for (int i = 0; i < 10; i++) {
      if (find.text("Login / Register").evaluate().isNotEmpty) break;
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.tap(find.text("Login / Register"));
    await tester.pumpAndSettle();

    // Login as admin
    await tester.enterText(find.byType(TextFormField).at(0), 'admin@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Carlo15045!');
    await tester.tap(find.text("Login"));
    await tester.pumpAndSettle();

    // ✅ Assumes "Admin Panel" text or button becomes visible
    expect(find.text("Admin"), findsOneWidget);
    await tester.tap(find.text("Admin"));
    await tester.pumpAndSettle();

    // Fill out a simple add event form
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Event');
    await tester.enterText(find.byType(TextFormField).at(1), 'This is an automated test event.');

    // Tap Add
    await tester.tap(find.text("Add Event"));
    await tester.pumpAndSettle();

    // Confirm success or presence of the new event
    expect(find.text("Test Event"), findsWidgets);

    // Logout
    await tester.tap(find.text("Logout"));
    await tester.pumpAndSettle();
    expect(find.text("Login / Register"), findsOneWidget);

    print("✅ Admin created an event and logged out");
  });
}

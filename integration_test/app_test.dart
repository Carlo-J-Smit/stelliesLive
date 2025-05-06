import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stellieslive/main.dart' as app;
import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Admin login → full event form (all fields) → logout", (
    tester,
  ) async {
    final random = Random();
    final isRecurring = random.nextBool();
    final now = DateTime.now();

    final testTitle = "Test Event ${now.millisecondsSinceEpoch}";
    final testVenue = "Test Venue";
    final testCategory = "Music";
    final testDescription = "This is an automated test of the admin panel.";
    final testImageUrl = "https://example.com/test.jpg";

    final start = now.add(Duration(minutes: random.nextInt(120)));
    final startTime =
        "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
    final startDate =
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";

    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final selectedDay = daysOfWeek[random.nextInt(7)];

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    for (int i = 0; i < 10; i++) {
      if (find.text("Login / Register").evaluate().isNotEmpty) break;
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.tap(find.text("Login / Register"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'admin@gmail.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Carlo15045!');
    await tester.tap(find.widgetWithText(ElevatedButton, "Login"));
    await tester.pumpAndSettle();
    await tester.pump(Duration(seconds: 5));

    // Tap the last navigation button (Admin)
    // final navButtons = find.byType(TextButton);
    // final adminButton = navButtons.evaluate().last;
    // await tester.tap(find.byWidget(adminButton.widget));
    await tester.tap(find.text("Admin"));
    await tester.pumpAndSettle();
    await tester.pump(Duration(seconds: 5));

    // Fill all the text fields
    await tester.enterText(
      find.byType(TextFormField).at(0),
      testTitle,
    ); // Title
    await tester.enterText(
      find.byType(TextFormField).at(1),
      testVenue,
    ); // Venue
    await tester.enterText(
      find.byType(TextFormField).at(2),
      testCategory,
    ); // Category
    await tester.enterText(
      find.byType(TextFormField).at(3),
      testDescription,
    ); // Description
    await tester.enterText(
      find.byType(TextFormField).at(4),
      testImageUrl,
    ); // Image URL

    if (isRecurring) {
      // Tap the recurring checkbox (should toggle recurring mode)
      final checkbox = find.byType(CheckboxListTile);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Select a day from the dropdown
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(selectedDay).last);
      await tester.pumpAndSettle();

      // Enter time only
      await tester.enterText(find.byType(TextFormField).at(5), startTime);
    } else {
      // Enter full date and time
      await tester.enterText(
        find.byType(TextFormField).at(5),
        "$startDate $startTime",
      );
    }

    tester.pump(Duration(seconds: 1));

    await tester.tap(find.text("Add Event"));
    await tester.pumpAndSettle();

    expect(find.text(testTitle), findsWidgets);
    await tester.tap(find.text("Logout"));
    await tester.pumpAndSettle();
    expect(find.text("Login / Register"), findsOneWidget);

    print(
      "✅ Admin created a ${isRecurring ? 'recurring' : 'one-time'} event and logged out",
    );
  });
}

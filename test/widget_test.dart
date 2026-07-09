import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:faster_app/core/widgets/glowing_button.dart';

void main() {
  testWidgets('GlowingButton displays text and triggers onPressed', (WidgetTester tester) async {
    bool pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlowingButton(
            text: 'TEST BUTTON',
            onPressed: () {
              pressed = true;
            },
          ),
        ),
      ),
    );

    // Verify that the button text is displayed.
    expect(find.text('TEST BUTTON'), findsOneWidget);

    // Tap the button.
    await tester.tap(find.text('TEST BUTTON'));
    await tester.pumpAndSettle();

    // Verify onPressed was triggered.
    expect(pressed, isTrue);
  });
}

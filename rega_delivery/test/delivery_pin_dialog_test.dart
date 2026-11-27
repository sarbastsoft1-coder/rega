import 'package:delivery_app/widgets/delivery_pin_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PIN confirm stays disabled until 4 digits', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showDeliveryPinDialog(
                  context,
                  title: 'Verify delivery',
                  hint: 'Enter the 4-digit code from the customer',
                  confirmLabel: 'Complete delivery',
                  cancelLabel: 'Cancel',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('delivery_pin_confirm'));
    expect(confirm, findsOneWidget);
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, '1234');
  });
}

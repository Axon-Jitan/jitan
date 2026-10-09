import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

Widget _field(TextEditingController controller, {int? maxLength}) => MaterialApp(
  home: Scaffold(
    body: JitanTextField(label: 'Employee code', controller: controller, maxLength: maxLength),
  ),
);

void main() {
  testWidgets('maxLength stops input at the limit and shows no counter', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_field(controller, maxLength: 5));

    await tester.enterText(find.byType(TextField), 'ABCDEFGH');

    expect(controller.text, 'ABCDE');
    expect(find.text('5/5'), findsNothing);
  });

  testWidgets('without maxLength, input is not limited', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_field(controller));

    await tester.enterText(find.byType(TextField), 'A' * 300);

    expect(controller.text, hasLength(300));
  });
}

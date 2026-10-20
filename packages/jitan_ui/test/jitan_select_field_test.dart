import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

Widget _field({String? value, ValueChanged<String?>? onChanged, String? errorText}) => MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(40),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          child: JitanSelectField<String>(
            label: 'Type',
            value: value,
            hintText: 'Choose',
            errorText: errorText,
            options: const [
              JitanSelectOption(value: 'work', label: 'Work hours'),
              JitanSelectOption(value: 'break', label: 'Break'),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the menu opens below the field, at its width, and never covers it', (tester) async {
    String? picked;
    await tester.pumpWidget(_field(value: 'work', onChanged: (v) => picked = v));

    final field = tester.getRect(find.text('Work hours'));
    final label = tester.getRect(find.text('Type'));
    await tester.tap(find.text('Work hours'));
    await tester.pumpAndSettle();

    final item = tester.getRect(find.widgetWithText(MenuItemButton, 'Work hours'));
    expect(item.top, greaterThan(field.bottom), reason: 'below the field');
    expect(item.top, greaterThan(label.bottom), reason: 'below the label');
    // The menu is as wide as the field; its items sit 6 px inside it.
    expect(tester.getSize(find.widgetWithText(MenuItemButton, 'Break')).width, 200 - 2 * 6);

    await tester.tap(find.widgetWithText(MenuItemButton, 'Break'));
    await tester.pumpAndSettle();
    expect(picked, 'break');
    expect(find.byType(MenuItemButton), findsNothing, reason: 'closes after a choice');
  });

  testWidgets('shows the hint without a value, the error below, and does not open when disabled', (tester) async {
    await tester.pumpWidget(_field(errorText: 'Choose a type.'));

    expect(find.text('Choose'), findsOneWidget);
    expect(find.text('Choose a type.'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
  });
}

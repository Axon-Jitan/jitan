import 'package:flutter/services.dart';
import 'package:jitan_models/jitan_models.dart';

/// Arranges a phone number while it is typed (`PhoneNumbers.asTyped`): only a
/// leading `+` and digits stay, grouped as the number's country writes them.
/// The server checks and stores the same form.
class PhoneNumberInputFormatter extends TextInputFormatter {
  const PhoneNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Deleting a space would put it straight back: delete the digit before it.
    var text = newValue.text;
    final removedOneSpace = oldValue.text.length == text.length + 1 &&
        oldValue.text.replaceAll(' ', '') == text.replaceAll(' ', '') &&
        newValue.selection.baseOffset > 0;
    if (removedOneSpace) {
      final at = newValue.selection.baseOffset;
      text = text.substring(0, at - 1) + text.substring(at);
    }
    final arranged = PhoneNumbers.asTyped(text);
    return TextEditingValue(text: arranged, selection: TextSelection.collapsed(offset: arranged.length));
  }
}

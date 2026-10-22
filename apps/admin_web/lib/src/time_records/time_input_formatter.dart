import 'package:flutter/services.dart';

/// Arranges what is typed into a time as `HH:mm`: digits only, at most four,
/// the colon added after the hours ("0830" → "08:30"). Whether the time is
/// valid is checked on save, by the client and again by the server.
class TimeInputFormatter extends TextInputFormatter {
  const TimeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length > 2 ? '${digits.substring(0, 2)}:${digits.substring(2)}' : digits;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

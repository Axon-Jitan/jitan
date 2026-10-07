import 'package:admin_web/src/common/relative_date_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 7, 0, 10);

  String text(DateTime moment) => relativeDateText(moment, now: now);

  test('uses calendar days, not 24-hour periods', () {
    expect(text(DateTime(2026, 10, 7, 0, 1)), 'Today');
    expect(text(DateTime(2026, 10, 6, 23, 50)), 'Yesterday');
  });

  test('treats a future moment (clock skew) as today', () {
    expect(text(DateTime(2026, 10, 8)), 'Today');
  });

  test('counts days, weeks, months and years with correct plurals', () {
    expect(text(DateTime(2026, 10, 5)), '2 days ago');
    expect(text(DateTime(2026, 9, 30)), '1 week ago');
    expect(text(DateTime(2026, 9, 20)), '2 weeks ago');
    expect(text(DateTime(2026, 9, 7)), '1 month ago');
    expect(text(DateTime(2026, 4, 7)), '6 months ago');
    expect(text(DateTime(2025, 10, 7)), '1 year ago');
    expect(text(DateTime(2023, 10, 1)), '3 years ago');
  });

  test('is not thrown off by a daylight-saving change', () {
    // Europe/Brussels switched to winter time on 25 Oct 2026.
    final afterSwitch = DateTime(2026, 10, 26, 0, 30);
    expect(relativeDateText(DateTime(2026, 10, 25, 0, 30), now: afterSwitch), 'Yesterday');
  });
}

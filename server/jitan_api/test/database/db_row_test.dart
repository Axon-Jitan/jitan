import 'package:jitan_api/src/database/db_row.dart';
import 'package:test/test.dart';

void main() {
  group('readBool', () {
    test('reads TINYINT(1) text values', () {
      const row = DbRow({'t': '1', 'f': '0'});
      expect(row.readBool('t'), isTrue);
      expect(row.readBool('f'), isFalse);
    });

    test('reads BIT(1) byte values', () {
      const row = DbRow({'t': '\u0001', 'f': '\u0000'});
      expect(row.readBool('t'), isTrue);
      expect(row.readBool('f'), isFalse);
    });

    test('rejects anything else instead of guessing', () {
      expect(() => const DbRow({'x': '2'}).readBool('x'), throwsStateError);
      expect(() => const DbRow({'x': null}).readBool('x'), throwsStateError);
    });
  });

  group('readInt', () {
    test('parses text integers', () {
      expect(const DbRow({'n': '48'}).readInt('n'), 48);
    });

    test('rejects NULL and non-numbers', () {
      expect(() => const DbRow({'n': null}).readInt('n'), throwsStateError);
      expect(() => const DbRow({'n': 'abc'}).readInt('n'), throwsStateError);
    });
  });

  group('readOptionalDateTime', () {
    test('parses a MySQL DATETIME as wall-clock time', () {
      final value = const DbRow({'d': '2026-10-07 09:30:15'}).readOptionalDateTime('d');
      expect(value, DateTime(2026, 10, 7, 9, 30, 15));
      expect(value!.isUtc, isFalse);
    });

    test('returns null for NULL', () {
      expect(const DbRow({'d': null}).readOptionalDateTime('d'), isNull);
    });
  });

  test('a missing column is a programming error, not a null', () {
    expect(() => const DbRow({'a': '1'}).readOptionalInt('b'), throwsStateError);
  });
}

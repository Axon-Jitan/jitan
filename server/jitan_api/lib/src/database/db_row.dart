/// One result row, with strict typed accessors.
///
/// The driver's text protocol returns every value as a string (or `null`).
/// These accessors convert and fail loudly on unexpected data instead of
/// guessing (ENGINEERING_RULES §20).
class DbRow {
  const DbRow(this._values);

  final Map<String, Object?> _values;

  int readInt(String column) {
    final value = readOptionalInt(column);
    if (value == null) throw _unexpected(column, 'NULL', 'an integer');
    return value;
  }

  int? readOptionalInt(String column) {
    final raw = _raw(column);
    if (raw == null) return null;
    if (raw is int) return raw;
    final parsed = int.tryParse(raw.toString());
    if (parsed == null) throw _unexpected(column, raw, 'an integer');
    return parsed;
  }

  /// Reads a `DOUBLE` column.
  double readDouble(String column) {
    final raw = _raw(column);
    final parsed = raw == null ? null : double.tryParse(raw.toString());
    if (parsed == null) throw _unexpected(column, raw ?? 'NULL', 'a number');
    return parsed;
  }

  String readString(String column) {
    final value = readOptionalString(column);
    if (value == null) throw _unexpected(column, 'NULL', 'a string');
    return value;
  }

  String? readOptionalString(String column) => _raw(column)?.toString();

  /// Reads an `...Active` / `...MFD` style flag.
  ///
  /// Accepts both `TINYINT(1)` (`"0"`/`"1"`) and `BIT(1)` (a single byte
  /// `\u0000`/`\u0001`), because the column type is not visible in the ERD.
  bool readBool(String column) {
    final raw = _raw(column);
    switch (raw) {
      case '1' || '\u0001' || 1 || true:
        return true;
      case '0' || '\u0000' || 0 || false:
        return false;
    }
    throw _unexpected(column, raw ?? 'NULL', 'a boolean flag');
  }

  /// A nullable flag: `null` stays `null` (not recorded), never `false`.
  bool? readOptionalBool(String column) => _raw(column) == null ? null : readBool(column);

  /// Reads a MySQL `DATETIME` (`yyyy-MM-dd HH:mm:ss[.ffffff]`) as a
  /// wall-clock [DateTime] without timezone (see ERD GAP-02).
  DateTime? readOptionalDateTime(String column) {
    final raw = _raw(column);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    if (parsed == null) throw _unexpected(column, raw, 'a DATETIME');
    return parsed;
  }

  /// Reads a MySQL `DATETIME` stored in UTC (registrations, TIME_ENGINE_ANALYSIS
  /// D9) as a UTC [DateTime].
  DateTime readUtcDateTime(String column) {
    final wallClock = readOptionalDateTime(column) ?? (throw _unexpected(column, 'NULL', 'a DATETIME'));
    return DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
      wallClock.millisecond,
    );
  }

  Object? _raw(String column) {
    if (!_values.containsKey(column)) {
      throw StateError('Result has no column "$column". Columns: ${_values.keys.join(', ')}');
    }
    return _values[column];
  }

  static StateError _unexpected(String column, Object value, String expected) =>
      StateError('Column "$column" holds "$value"; expected $expected.');
}

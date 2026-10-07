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

  String readString(String column) {
    final raw = _raw(column);
    if (raw == null) throw _unexpected(column, 'NULL', 'a string');
    return raw.toString();
  }

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

  /// Reads a MySQL `DATETIME` (`yyyy-MM-dd HH:mm:ss[.ffffff]`) as a
  /// wall-clock [DateTime] without timezone (see ERD GAP-02).
  DateTime? readOptionalDateTime(String column) {
    final raw = _raw(column);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
    if (parsed == null) throw _unexpected(column, raw, 'a DATETIME');
    return parsed;
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

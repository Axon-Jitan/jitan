/// Strict accessors for decoding API JSON.
///
/// Every accessor throws [FormatException] naming the offending key, so a
/// contract mismatch between server and client fails loudly instead of being
/// silently coerced.
extension JsonReading on Map<String, Object?> {
  String readString(String key) {
    final value = this[key];
    if (value is String) return value;
    throw FormatException('Expected "$key" to be a string, got ${value.runtimeType}.');
  }

  String? readOptionalString(String key) {
    final value = this[key];
    if (value == null || value is String) return value as String?;
    throw FormatException('Expected "$key" to be a string or null, got ${value.runtimeType}.');
  }

  List<String> readStringList(String key) {
    final value = this[key];
    if (value is List<Object?> && value.every((item) => item is String)) return value.cast<String>();
    throw FormatException('Expected "$key" to be a list of strings, got ${value.runtimeType}.');
  }

  List<int> readIntList(String key) {
    final value = this[key];
    if (value is List<Object?> && value.every((item) => item is int)) return value.cast<int>();
    throw FormatException('Expected "$key" to be a list of integers, got ${value.runtimeType}.');
  }

  int? readOptionalInt(String key) {
    final value = this[key];
    if (value == null || value is int) return value as int?;
    throw FormatException('Expected "$key" to be an integer or null, got ${value.runtimeType}.');
  }

  int readInt(String key) {
    final value = this[key];
    if (value is int) return value;
    throw FormatException('Expected "$key" to be an integer, got ${value.runtimeType}.');
  }

  /// A number; JSON does not tell `50` from `50.0`.
  double readDouble(String key) {
    final value = this[key];
    if (value is num) return value.toDouble();
    throw FormatException('Expected "$key" to be a number, got ${value.runtimeType}.');
  }

  bool readBool(String key) {
    final value = this[key];
    if (value is bool) return value;
    throw FormatException('Expected "$key" to be a boolean, got ${value.runtimeType}.');
  }

  bool? readOptionalBool(String key) {
    final value = this[key];
    if (value == null || value is bool) return value as bool?;
    throw FormatException('Expected "$key" to be a boolean or null, got ${value.runtimeType}.');
  }

  DateTime? readOptionalDateTime(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return DateTime.parse(value);
    throw FormatException('Expected "$key" to be a date-time string or null, got ${value.runtimeType}.');
  }

  Map<String, Object?> readObject(String key) {
    final value = this[key];
    if (value is Map<String, Object?>) return value;
    throw FormatException('Expected "$key" to be an object, got ${value.runtimeType}.');
  }

  List<Map<String, Object?>> readObjectList(String key) {
    final value = this[key];
    if (value is List<Object?>) {
      return [
        for (final item in value)
          if (item is Map<String, Object?>)
            item
          else
            throw FormatException('Expected every item of "$key" to be an object.'),
      ];
    }
    throw FormatException('Expected "$key" to be a list, got ${value.runtimeType}.');
  }
}

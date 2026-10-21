/// An SQL `IN (…)` list built from bound parameters (ENGINEERING_RULES §28a):
/// the statement only ever contains placeholders (`:u0, :u1, …`), never the
/// values themselves.
///
/// ```dart
/// final ids = SqlInList('u', userIds);
/// db.query('… WHERE userID IN (${ids.placeholders})', {...ids.params});
/// ```
class SqlInList {
  /// [prefix] names the placeholders; use a different one for each list in
  /// one statement. [values] must not be empty (`IN ()` is not valid SQL).
  SqlInList(this.prefix, Iterable<Object?> values) : _values = values.toList() {
    if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(prefix)) {
      throw ArgumentError.value(prefix, 'prefix', 'must be a short identifier written in the code');
    }
    if (_values.isEmpty) throw ArgumentError.value(values, 'values', 'must not be empty');
  }

  final String prefix;
  final List<Object?> _values;

  /// `:prefix0, :prefix1, …`, for inside `IN (…)`.
  String get placeholders => [for (var i = 0; i < _values.length; i++) ':$prefix$i'].join(', ');

  /// The values, keyed by their placeholder names.
  Map<String, Object?> get params => {for (final (i, value) in _values.indexed) '$prefix$i': value};
}

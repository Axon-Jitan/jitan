/// Slows password guessing: after [maxFailures] wrong attempts on one employee
/// code, that code can't sign in until [window] has passed since the last
/// failure (SEC-01). Unknown codes count too, so the limit never shows which
/// codes exist. Per code, not per address: behind Nginx every request can come
/// from the same address.
///
/// In memory: one server process, and a restart forgets the counts, which only
/// favours the person waiting. A guesser can lock a known code for [window] at
/// a time; a real employee can use the phone they are already signed in on.
class SignInThrottle {
  SignInThrottle({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const maxFailures = 5;
  static const window = Duration(minutes: 15);

  /// Bounds the memory one flood of made-up codes can take.
  static const _maxTracked = 10000;

  final DateTime Function() _clock;
  final _failures = <String, ({int count, DateTime last})>{};

  static String _key(String code) => code.trim().toLowerCase();

  bool _expired(({int count, DateTime last}) entry) => _clock().difference(entry.last) >= window;

  /// Whether [code] has used up its attempts.
  bool isBlocked(String code) {
    final entry = _failures[_key(code)];
    if (entry == null) return false;
    if (_expired(entry)) {
      _failures.remove(_key(code));
      return false;
    }
    return entry.count >= maxFailures;
  }

  void failed(String code) {
    if (_failures.length >= _maxTracked) _failures.removeWhere((_, entry) => _expired(entry));
    if (_failures.length >= _maxTracked) _failures.remove(_failures.keys.first);
    final key = _key(code);
    final entry = _failures[key];
    final count = entry == null || _expired(entry) ? 1 : entry.count + 1;
    _failures[key] = (count: count, last: _clock());
  }

  void succeeded(String code) => _failures.remove(_key(code));
}

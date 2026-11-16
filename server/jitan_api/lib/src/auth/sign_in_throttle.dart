/// Slows password guessing: after [maxFailures] wrong attempts on one employee
/// code, that code can't sign in until [window] has passed since the last
/// failure (SEC-01). Unknown codes count too, so the limit never shows which
/// codes exist. Per code, not per address: behind Nginx every request can come
/// from the same address.
///
/// Review M2 (2026-11-16):
/// - An attempt is counted when it starts ([begin]), not after the slow
///   password check, so parallel guesses share the same five attempts.
/// - The key ignores capitals and accents, as the database matches codes
///   (`EMPÉ01` and `EMPE01` are one account, so one count).
/// - A count that still blocks, or attempts still running, are never dropped
///   to make room; when the table is full of them, new codes wait (429).
///
/// In memory: one server process, and a restart forgets the counts, which only
/// favours the person waiting. A guesser can lock a known code for [window] at
/// a time; a real employee can use the phone they are already signed in on.
class SignInThrottle {
  SignInThrottle({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const maxFailures = 5;
  static const window = Duration(minutes: 15);

  /// Bounds the memory one flood of made-up codes can take.
  static const maxTracked = 10000;

  final DateTime Function() _clock;
  final _entries = <String, _Entry>{};

  /// Lower case, accents taken off the Latin letters codes use.
  static String keyOf(String code) {
    final lower = code.trim().toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      out.write(_plain[char] ?? char);
    }
    return out.toString();
  }

  bool _expired(_Entry entry) => entry.running == 0 && _clock().difference(entry.last) >= window;

  /// Whether [code] may try now. When it may, the attempt is counted at once
  /// and must be ended with [succeeded] or [failed].
  bool begin(String code) {
    final key = keyOf(code);
    var entry = _entries[key];
    if (entry != null && _expired(entry)) {
      _entries.remove(key);
      entry = null;
    }
    if (entry == null) {
      if (!_makeRoom()) return false;
      entry = _entries[key] = _Entry(_clock());
    }
    if (entry.failures + entry.running >= maxFailures) return false;
    entry.running++;
    return true;
  }

  void failed(String code) {
    final entry = _entries[keyOf(code)];
    if (entry == null) return;
    entry
      ..running = (entry.running - 1).clamp(0, maxFailures)
      ..failures += 1
      ..last = _clock();
  }

  void succeeded(String code) {
    final entry = _entries[keyOf(code)];
    if (entry == null) return;
    entry.running = (entry.running - 1).clamp(0, maxFailures);
    if (entry.running == 0) _entries.remove(keyOf(code));
  }

  /// Room for one more code: expired entries go first, then the oldest one
  /// that neither blocks nor has an attempt running. `false` when every entry
  /// still matters.
  bool _makeRoom() {
    if (_entries.length < maxTracked) return true;
    _entries.removeWhere((_, entry) => _expired(entry));
    if (_entries.length < maxTracked) return true;
    final spare = _entries.entries.where((e) => e.value.running == 0 && e.value.failures < maxFailures).firstOrNull;
    if (spare == null) return false;
    _entries.remove(spare.key);
    return true;
  }

  static const _plain = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
    'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ı': 'i',
    'ľ': 'l', 'ĺ': 'l', 'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
    'ŕ': 'r', 'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ß': 'ss', 'ť': 't', 'ţ': 't',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
    'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
  };
}

class _Entry {
  _Entry(this.last);

  int failures = 0;
  int running = 0;
  DateTime last;
}

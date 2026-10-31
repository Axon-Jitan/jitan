import 'session_store_stub.dart' if (dart.library.js_interop) 'session_store_web.dart' as platform;

/// Survives closing the browser (the 30-day sign-in). Not encrypted: the page
/// must never load scripts from elsewhere.
abstract interface class SessionStore {
  String? read(String key);
  void write(String key, String value);
  void delete(String key);
}

/// The browser's local storage; in memory outside the web.
SessionStore browserSessionStore() => platform.browserSessionStore();

/// For tests and platforms without a browser.
class MemorySessionStore implements SessionStore {
  MemorySessionStore([Map<String, String>? values]) : values = values ?? {};

  final Map<String, String> values;

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void delete(String key) => values.remove(key);
}

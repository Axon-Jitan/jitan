import 'package:web/web.dart' as web;

import 'session_store.dart';

SessionStore browserSessionStore() => _LocalStorageSessionStore();

class _LocalStorageSessionStore implements SessionStore {
  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String value) => web.window.localStorage.setItem(key, value);

  @override
  void delete(String key) => web.window.localStorage.removeItem(key);
}

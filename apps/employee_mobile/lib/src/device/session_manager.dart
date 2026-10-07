import 'dart:convert';
import 'dart:math';

import 'package:jitan_models/jitan_models.dart';

import 'secure_store.dart';

/// This device's sign-in: the session token from onboarding (later also
/// from sign-in, AUTH-01) and the device id it was issued for.
///
/// The token is kept in [SecureStore] only, and in memory while the app
/// runs; it is never logged. The API client reads [accessToken] on every
/// request.
class SessionManager {
  SessionManager(this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SecureStore _store;
  final DateTime Function() _clock;

  static const _tokenKey = 'session.token';
  static const _expiresKey = 'session.expiresAt';
  static const _deviceKey = 'device.id';

  String? _token;

  /// The current session token, or `null` when signed out.
  String? get accessToken => _token;

  bool get isSignedIn => _token != null;

  /// Loads a stored, unexpired session. Returns whether one was found; an
  /// expired or unreadable one is removed.
  Future<bool> restore() async {
    final token = await _store.read(_tokenKey);
    final expiresAt = DateTime.tryParse(await _store.read(_expiresKey) ?? '');
    if (token == null || expiresAt == null || !expiresAt.isAfter(_clock())) {
      if (token != null) await clear();
      return false;
    }
    _token = token;
    return true;
  }

  /// Stores [session]. Throws when the platform storage fails; the caller
  /// then offers to retry (Figma "Session recovery").
  Future<void> save(SessionInfo session) async {
    await _store.write(_tokenKey, session.accessToken);
    await _store.write(_expiresKey, session.expiresAt.toUtc().toIso8601String());
    _token = session.accessToken;
  }

  /// Signs this device out (session expired or revoked, or sign-out).
  Future<void> clear() async {
    _token = null;
    await _store.delete(_tokenKey);
    await _store.delete(_expiresKey);
  }

  /// A random id for this installation, created once and kept until the app
  /// is uninstalled. It is sent with onboarding so the session names the
  /// device (GAP-05: not stored on the server).
  Future<String> deviceId() async {
    final existing = await _store.read(_deviceKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final id = base64Url.encode([for (var i = 0; i < 24; i++) random.nextInt(256)]).replaceAll('=', '');
    await _store.write(_deviceKey, id);
    return id;
  }
}

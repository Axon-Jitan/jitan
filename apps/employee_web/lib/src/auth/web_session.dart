import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

enum WebSessionStatus { checking, signedOut, signedIn }

/// This browser's sign-in: stays until the session ends, Sign out, or the
/// server refuses it. The token is only carried, and never logged.
class WebSession extends ChangeNotifier {
  WebSession({required this._auth, required this._me, required this._store, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AuthApi _auth;
  final MeApi _me;
  final SessionStore _store;
  final DateTime Function() _clock;

  static const _tokenKey = 'jitan.employee.token';
  static const _expiresKey = 'jitan.employee.expiresAt';
  static const _deviceKey = 'jitan.employee.deviceId';

  WebSessionStatus _status = WebSessionStatus.checking;
  WebSessionStatus get status => _status;

  EmployeeAccount? _account;
  EmployeeAccount? get account => _account;

  String? _token;

  /// Read by the API client on every request.
  String? get token => _token;

  bool _disposed = false;

  /// Opens the site: a stored, unexpired session the server still accepts.
  /// With no connection it stays signed in, and the pages say so.
  Future<void> restore() async {
    final token = _store.read(_tokenKey);
    final expiresAt = DateTime.tryParse(_store.read(_expiresKey) ?? '');
    if (token == null || expiresAt == null || !expiresAt.isAfter(_clock())) return _end();
    _token = token;
    try {
      _account = await _me.me();
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return _end();
    }
    _set(WebSessionStatus.signedIn);
  }

  /// Throws [ApiClientException] for the sign-in screen to show.
  Future<void> signIn(String code, String password) async {
    final session = await _auth.signIn(SignInRequest(code: code, password: password, deviceId: _deviceId()));
    _keep(session);
    _account = session.account;
    _set(WebSessionStatus.signedIn);
  }

  /// A new password ends every session, so it comes with a new one.
  Future<void> changePassword(String current, String next) async =>
      _keep(await _me.changePassword(currentPassword: current, newPassword: next));

  void _keep(SessionResponse session) {
    _token = session.session.accessToken;
    _store.write(_tokenKey, session.session.accessToken);
    _store.write(_expiresKey, session.session.expiresAt.toUtc().toIso8601String());
  }

  /// The session is stateless (GAP-05): forgetting the token ends it here.
  void signOut() => _end();

  /// A request came back 401: the session ended on the server.
  void sessionRefused() {
    if (_status == WebSessionStatus.signedIn) _end();
  }

  void _end() {
    _token = null;
    _account = null;
    _store.delete(_tokenKey);
    _store.delete(_expiresKey);
    _set(WebSessionStatus.signedOut);
  }

  void _set(WebSessionStatus status) {
    _status = status;
    if (!_disposed) notifyListeners();
  }

  /// A random id for this browser, as UUID v4.
  String _deviceId() {
    final stored = _store.read(_deviceKey);
    if (stored != null) return stored;
    final random = Random.secure();
    final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    _store.write(_deviceKey, id);
    return id;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

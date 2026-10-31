import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import 'platform/session_store.dart';

/// Where the app stands with the signed-in person.
enum AdminSessionStatus {
  /// Reading the stored session.
  checking,
  signedOut,
  signedIn,

  /// Signed in, but the server gives this account no HR access (Figma `1469:44`).
  noAccess,
}

/// This browser's HR sign-in: stays for the session's 30 days (product owner,
/// 2026-10-31), until Sign out or until the server refuses it. The server
/// decides everything; the token is only carried, and never logged.
class AdminSession extends ChangeNotifier {
  AdminSession({
    required this._auth,
    required this._me,
    required this._companies,
    required this._store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Already signed in, for tests of the pages behind sign-in.
  @visibleForTesting
  AdminSession.signedIn({
    required this._auth,
    required this._me,
    required this._companies,
    required this._store,
    required EmployeeAccount this._account,
  }) : _clock = DateTime.now,
       _status = AdminSessionStatus.signedIn;

  final AuthApi _auth;
  final MeApi _me;
  final CompaniesApi _companies;
  final SessionStore _store;
  final DateTime Function() _clock;

  static const _tokenKey = 'jitan.session.token';
  static const _expiresKey = 'jitan.session.expiresAt';
  static const _deviceKey = 'jitan.device.id';

  AdminSessionStatus _status = AdminSessionStatus.checking;
  AdminSessionStatus get status => _status;

  EmployeeAccount? _account;
  EmployeeAccount? get account => _account;

  String? _token;

  /// Read by the API client on every request.
  String? get token => _token;

  bool _disposed = false;

  /// Opens the app: a stored, unexpired session the server still accepts.
  /// Offline it stays signed in, and the pages say what they can't load.
  Future<void> restore() async {
    final token = _store.read(_tokenKey);
    final expiresAt = DateTime.tryParse(_store.read(_expiresKey) ?? '');
    if (token == null || expiresAt == null || !expiresAt.isAfter(_clock())) return _end();
    _token = token;
    try {
      _account = await _me.me();
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return _end();
      return _set(AdminSessionStatus.signedIn);
    }
    await _checkAccess();
  }

  /// Throws [ApiClientException] for the sign-in screen to show.
  Future<void> signIn(String code, String password) async {
    final session = await _auth.signIn(SignInRequest(code: code, password: password, deviceId: _deviceId()));
    _token = session.session.accessToken;
    _account = session.account;
    _store.write(_tokenKey, session.session.accessToken);
    _store.write(_expiresKey, session.session.expiresAt.toUtc().toIso8601String());
    await _checkAccess();
  }

  /// The session is stateless (GAP-05): forgetting the token ends it here.
  void signOut() => _end();

  /// A request came back 401: the session ended on the server (expired, a new
  /// password, the account switched off).
  void sessionRefused() {
    if (_status == AdminSessionStatus.signedIn || _status == AdminSessionStatus.noAccess) _end();
  }

  Future<void> _checkAccess() async {
    try {
      await _companies.listCompanies();
      _set(AdminSessionStatus.signedIn);
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return _end();
      _set(e.statusCode == 403 ? AdminSessionStatus.noAccess : AdminSessionStatus.signedIn);
    }
  }

  void _end() {
    _token = null;
    _account = null;
    _store.delete(_tokenKey);
    _store.delete(_expiresKey);
    _set(AdminSessionStatus.signedOut);
  }

  void _set(AdminSessionStatus status) {
    _status = status;
    if (!_disposed) notifyListeners();
  }

  /// A random id for this browser, as UUID v4 (like the phone's).
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

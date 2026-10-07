import 'dart:convert';

import 'package:employee_mobile/src/app/employee_services.dart';
import 'package:employee_mobile/src/device/device_settings.dart';
import 'package:employee_mobile/src/device/permissions_gateway.dart';
import 'package:employee_mobile/src/device/secure_store.dart';
import 'package:employee_mobile/src/device/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';

const testQr = 'qr-AAAAAAAAAAAAAAAAAAAAAAAA';

/// Tap target of the fake embedded camera ([TestHarness]).
const fakeCameraKey = ValueKey('fake-camera');

/// The Jitan API as onboarding sees it, in memory, over the real API client:
/// the same rules as the server (re-onboarding guard, session recovery with
/// the same password, bearer token for `/me`).
class FakeJitanServer {
  /// Whether the employee behind [testQr] has set a password.
  String? password;
  bool active = true;

  /// The next request to these paths fails without a response.
  final dropNext = <String>{};

  /// The response to `/onboarding/complete` is lost after the server
  /// completed (the device sees a network failure).
  bool loseCompleteResponse = false;

  /// `/onboarding/complete` answers 409 as if another device won the race.
  bool anotherDeviceWins = false;

  /// `/onboarding/complete` refuses the password (server-side policy).
  bool rejectPassword = false;

  /// Languages served besides built-in English.
  List<Map<String, Object?>> languages = [
    {'id': 2, 'code': 'nl', 'name': 'Nederlands'},
  ];

  final requests = <http.Request>[];
  final issuedTokens = <String>[];
  var _tokenCount = 0;

  Map<String, Object?> get _account => {
    'firstName': 'Disan',
    'lastName': 'Ssebowa',
    'code': 'SBW',
    'companies': ['Almeco'],
  };

  late final client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (dropNext.remove(path)) throw http.ClientException('connection reset');
    return switch (path) {
      '/onboarding/start' => _start(request),
      '/onboarding/complete' => _complete(request),
      '/languages' => _json({'languages': languages}),
      '/translations' => _json({
        'language': request.url.queryParameters['language'],
        'translations': {'onboarding.method.title': 'Hoe wil je je tijd registreren?'},
      }),
      '/me' => _me(request),
      '/auth/sign-in' => _signIn(request),
      '/me/password' => _changePassword(request),
      '/me/language' => _json({'languageCode': null}),
      _ => _error(404, 'not_found'),
    };
  });

  http.Response _start(http.Request request) {
    final qr = (jsonDecode(request.body) as Map)['qrCode'];
    if (qr != testQr) return _error(404, 'invalid_qr_code');
    if (!active) return _error(403, 'account_inactive');
    if (password != null) return _error(409, 'onboarding_already_completed');
    return _json(_account);
  }

  http.Response _complete(http.Request request) {
    final body = jsonDecode(request.body) as Map;
    if (body['qrCode'] != testQr) return _error(404, 'invalid_qr_code');
    if (!active) return _error(403, 'account_inactive');
    if (rejectPassword) {
      return http.Response(
        jsonEncode({
          'error': {'code': 'validation_failed', 'message': 'x', 'field': 'password'},
        }),
        400,
      );
    }
    if (anotherDeviceWins) {
      password = 'someone else';
      return _error(409, 'onboarding_already_completed');
    }
    if (password != null && password != body['password']) return _error(409, 'onboarding_already_completed');
    password = body['password'] as String;
    if (loseCompleteResponse) {
      loseCompleteResponse = false;
      throw http.ClientException('response lost');
    }
    final token = 'token-${++_tokenCount}';
    issuedTokens.add(token);
    return _json({
      'account': _account,
      'session': {'accessToken': token, 'expiresAt': '2099-01-01T00:00:00.000Z'},
    });
  }

  bool _authorized(http.Request request) {
    final auth = request.headers['authorization'];
    return auth != null && issuedTokens.contains(auth.replaceFirst('Bearer ', ''));
  }

  http.Response _me(http.Request request) => _authorized(request) ? _json(_account) : _error(401, 'unauthenticated');

  http.Response _session() {
    final token = 'token-${++_tokenCount}';
    issuedTokens.add(token);
    return _json({
      'account': _account,
      'session': {'accessToken': token, 'expiresAt': '2099-01-01T00:00:00.000Z'},
    });
  }

  /// Same rules as the server: generic failure unless code and password
  /// match; an inactive account is reported only for the right password.
  http.Response _signIn(http.Request request) {
    final body = jsonDecode(request.body) as Map;
    if (body['code'] != 'SBW' || password == null || body['password'] != password) {
      return _error(401, 'invalid_credentials');
    }
    if (!active) return _error(403, 'account_inactive');
    return _session();
  }

  /// New password: every existing session ends, this device gets a new one.
  http.Response _changePassword(http.Request request) {
    if (!_authorized(request)) return _error(401, 'unauthenticated');
    final newPassword = (jsonDecode(request.body) as Map)['newPassword'] as String;
    if (rejectPassword) {
      return http.Response(
        jsonEncode({
          'error': {'code': 'validation_failed', 'message': 'x', 'field': 'newPassword'},
        }),
        400,
      );
    }
    password = newPassword;
    issuedTokens.clear();
    return _session();
  }

  static http.Response _json(Object body) =>
      http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

  static http.Response _error(int status, String code) => http.Response(
    jsonEncode({
      'error': {'code': code, 'message': code},
    }),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// Requests to [path], in order.
  List<http.Request> requestsTo(String path) => [for (final r in requests) if (r.url.path == path) r];
}

class MemorySecureStore implements SecureStore {
  final values = <String, String>{};

  /// Writes fail (e.g. Keystore unavailable).
  bool failWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('secure storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class FakePermissions implements PermissionsGateway {
  bool grantLocation = true;
  bool grantNotifications = true;
  final asked = <String>[];

  @override
  Future<bool> requestLocation() async {
    asked.add('location');
    return grantLocation;
  }

  @override
  Future<bool> requestNotifications() async {
    asked.add('notifications');
    return grantNotifications;
  }
}

/// The app's services against [FakeJitanServer], plus device fakes.
class TestHarness {
  TestHarness({DateTime Function()? clock}) {
    session = SessionManager(store, clock: clock);
    final transport = ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: server.client,
      accessToken: () => session.accessToken,
    );
    final languagesApi = LanguagesApi(transport);
    services = EmployeeServices(
      onboardingApi: OnboardingApi(transport),
      authApi: AuthApi(transport),
      languagesApi: languagesApi,
      meApi: MeApi(transport),
      translationService: TranslationService(languagesApi),
      session: session,
      settings: DeviceSettings(store),
      permissions: permissions,
      scanQr: (_) async => scannedValue,
      // The embedded camera of "Recover with QR": a button that "reads"
      // [scannedValue].
      qrScannerView: (onDetected) => Center(
        child: TextButton(
          key: fakeCameraKey,
          onPressed: () {
            final value = scannedValue;
            if (value != null) onDetected(value);
          },
          child: const Text('fake camera'),
        ),
      ),
    );
  }

  final server = FakeJitanServer();
  final store = MemorySecureStore();
  final permissions = FakePermissions();
  late final SessionManager session;
  late final EmployeeServices services;

  /// What the fake camera reads; `null` = the employee closed the scanner.
  String? scannedValue = testQr;
}

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

/// A temporary onboarding QR HR/Admin generated for the employee.
const testQr = 'onboarding-qr.AAAAAAAAAAAAAAAA.sig';

/// A temporary recovery QR HR/Admin generated after Reset account access.
const recoveryQr = 'recovery-qr.BBBBBBBBBBBBBBBB.sig';

/// The employee's permanent Terminal QR: it must never onboard or recover.
const terminalQr = 'terminal-qr-CCCCCCCCCCCCCCCC';

/// Tap target of the fake embedded camera ([TestHarness]).
const fakeCameraKey = ValueKey('fake-camera');

/// The Jitan API as the app sees it, in memory, over the real API client:
/// the same rules as the server (temporary QRs by purpose, single use,
/// expiry; re-onboarding guard; the same device finishing with the same
/// password; bearer token for `/me`).
class FakeJitanServer {
  /// Temporary QRs that expired or were replaced.
  final expiredQrs = <String>{};

  /// Temporary QRs that were used (with the password they set).
  final usedQrs = <String, String>{};

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
    {'id': 3, 'code': 'fr', 'name': 'Français'},
    {'id': 4, 'code': 'de', 'name': 'Deutsch'},
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
      '/recovery/start' => _recoveryStart(request),
      '/recovery/complete' => _recoveryComplete(request),
      '/languages' => _json({'languages': languages}),
      '/translations' => _json({
        'language': request.url.queryParameters['language'],
        'translations': {'onboarding.password.title': 'Stel je wachtwoord in', 'language.name.fr': 'Frans'},
      }),
      '/me' => _me(request),
      '/auth/sign-in' => _signIn(request),
      '/me/password' => _changePassword(request),
      '/me/language' => _json({'languageCode': null}),
      '/me/today' => _today(request),
      '/me/time-registrations' => _register(request),
      _ => _error(404, 'not_found'),
    };
  });

  /// The common QR checks: the purpose's own QR, unexpired, unused.
  http.Response? _qrRefusal(Object? qr, {required String expected, required String other}) {
    if (qr == other) return _error(400, 'qr_wrong_purpose');
    if (qr != expected) return _error(400, 'invalid_qr_code');
    if (expiredQrs.contains(qr)) return _error(410, 'qr_expired');
    return null;
  }

  http.Response _start(http.Request request) {
    final qr = (jsonDecode(request.body) as Map)['qrCode'];
    final refusal = _qrRefusal(qr, expected: testQr, other: recoveryQr);
    if (refusal != null) return refusal;
    if (usedQrs.containsKey(qr)) return _error(409, 'qr_already_used');
    if (!active) return _error(403, 'account_inactive');
    if (password != null) return _error(409, 'onboarding_already_completed');
    return _json(_account);
  }

  http.Response _complete(http.Request request) {
    final body = jsonDecode(request.body) as Map;
    final refusal = _qrRefusal(body['qrCode'], expected: testQr, other: recoveryQr);
    if (refusal != null) return refusal;
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
    usedQrs[testQr] = password!;
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

  http.Response _recoveryStart(http.Request request) {
    final qr = (jsonDecode(request.body) as Map)['qrCode'];
    final refusal = _qrRefusal(qr, expected: recoveryQr, other: testQr);
    if (refusal != null) return refusal;
    if (usedQrs.containsKey(qr)) return _error(409, 'qr_already_used');
    if (!active) return _error(403, 'account_inactive');
    if (password != null) return _error(409, 'account_not_reset');
    return _json(_account);
  }

  http.Response _recoveryComplete(http.Request request) {
    final body = jsonDecode(request.body) as Map;
    final refusal = _qrRefusal(body['qrCode'], expected: recoveryQr, other: testQr);
    if (refusal != null) return refusal;
    if (!active) return _error(403, 'account_inactive');
    if (anotherDeviceWins) {
      usedQrs[recoveryQr] = 'someone else';
      return _error(409, 'qr_already_used');
    }
    final usedWith = usedQrs[recoveryQr];
    if (usedWith != null && usedWith != body['password']) return _error(409, 'qr_already_used');
    if (usedWith == null && password != null) return _error(409, 'account_not_reset');
    password = body['password'] as String;
    usedQrs[recoveryQr] = password!;
    return _session();
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
    final body = jsonDecode(request.body) as Map;
    final newPassword = body['newPassword'] as String;
    if (body['currentPassword'] != password) {
      return http.Response(
        jsonEncode({
          'error': {'code': 'validation_failed', 'message': 'x', 'field': 'currentPassword'},
        }),
        400,
      );
    }
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

  // Today (GET /me/today, POST /me/time-registrations), with the server's
  // rules: a corrected time waits for HR (D31); a finished day's registered
  // time is finish − start − break (D13). No rounding in this schedule.

  /// The employee never registered: "When did you arrive?" (first day).
  bool firstDay = false;
  String? scheduledStart = '08:00';
  String? scheduledFinish = '16:30';
  int? breakMinutes = 30;
  String? breakStart = '12:00';
  String? breakFinish = '12:30';

  /// The registration bodies received, in order.
  final registrations = <Map<String, Object?>>[];

  /// The next registration is refused with this error code (e.g.
  /// `validation_failed`).
  String? refuseNextRegistration;

  http.Response _register(http.Request request) {
    if (!_authorized(request)) return _error(401, 'unauthenticated');
    if (refuseNextRegistration case final code?) {
      refuseNextRegistration = null;
      return _error(400, code);
    }
    final body = (jsonDecode(request.body) as Map).cast<String, Object?>();
    registrations.add(body);
    firstDay = false;
    final corrected = body['entry'] == 'corrected';
    return http.Response(
      jsonEncode({
        'boundary': body['boundary'],
        'actualId': registrations.length * 2,
        'actualAt': body['at'],
        'roundedId': corrected ? null : registrations.length * 2 + 1,
        'roundedAt': corrected ? null : body['at'],
      }),
      201,
    );
  }

  http.Response _today(http.Request request) {
    if (!_authorized(request)) return _error(401, 'unauthenticated');
    String local(DateTime at) =>
        '${at.toLocal().hour.toString().padLeft(2, '0')}:${at.toLocal().minute.toString().padLeft(2, '0')}';
    final times = <String, Map<String, Object?>>{};
    final pending = <Map<String, Object?>>[];
    for (final (i, r) in registrations.indexed) {
      final at = DateTime.parse(r['at']! as String);
      if (r['entry'] == 'corrected') {
        pending.add({
          'id': i + 1,
          'boundary': r['boundary'],
          'requested': at.toIso8601String(),
          'requestedLocal': local(at),
          'reason': r['reason'],
        });
      } else {
        times[r['boundary']! as String] = {
          'actualId': i + 1,
          'actual': at.toIso8601String(),
          'rounded': at.toIso8601String(),
          'method': 'manual',
          'enteredByHand': false,
          'actualLocal': local(at),
          'roundedLocal': local(at),
        };
      }
    }
    final start = times['start'];
    final finish = times['finish'];
    final status = pending.isNotEmpty
        ? 'pending_review'
        : start != null && finish != null
        ? 'complete'
        : start != null
        ? 'working'
        : 'missing_start';
    int? minutes;
    if (start != null && finish != null && pending.isEmpty) {
      minutes = DateTime.parse(finish['rounded']! as String).difference(DateTime.parse(start['rounded']! as String)).inMinutes -
          (breakMinutes ?? 0);
    }
    return _json({
      'date': '2026-10-22',
      'firstDay': firstDay,
      'scheduledStart': scheduledStart,
      'scheduledFinish': scheduledFinish,
      'breakMinutes': breakMinutes,
      'breakStart': breakStart,
      'breakFinish': breakFinish,
      'day': registrations.isEmpty
          ? null
          : {
              'employeeId': 1,
              'employeeCode': '',
              'date': '2026-10-22',
              'status': status,
              'start': start,
              'finish': finish,
              'pending': pending,
            },
      'registeredMinutes': minutes,
    });
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
      recoveryApi: RecoveryApi(transport),
      authApi: AuthApi(transport),
      languagesApi: languagesApi,
      meApi: MeApi(transport),
      timeRegistrationsApi: TimeRegistrationsApi(transport),
      // 09:00 on Thursday 22 October 2026 unless a test says otherwise.
      clock: clock ?? () => DateTime(2026, 10, 22, 9),
      translationService: TranslationService(languagesApi),
      session: session,
      settings: DeviceSettings(store),
      permissions: permissions,
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

import 'dart:convert';

import 'package:employee_web/src/app/web_services.dart';
import 'package:employee_web/src/auth/web_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

final towers = MyProject(
  id: 1,
  name: 'P-1042 Office refurbishment',
  isClient: true,
  placeName: 'Mouscron',
  lastUsed: DateTime.utc(2026, 11, 2, 7),
);
const workshop = MyProject(id: 2, name: 'P-0990 Clean the workshop', isClient: false, placeName: 'Almeco');
const warehouse = MyProject(id: 3, name: 'P-1063 Warehouse fit-out', isClient: true, placeName: 'Kortrijk');
const almeco = MyCompany(id: 7, name: 'Almeco', isDefault: true);
const pca = MyCompany(id: 8, name: 'PCA', isDefault: false);

TimeRecordTime time(String local, DateTime at) => TimeRecordTime(actualId: 1, actual: at, rounded: at, actualLocal: local, method: TimeRecordMethod.geofence, enteredByHand: false);

TimeRecordDay record({required DateTime date, TimeRecordStatus status = TimeRecordStatus.working, TimeRecordTime? start, TimeRecordTime? finish}) =>
    TimeRecordDay(employeeId: 1, employeeCode: 'SBW', date: date, status: status, start: start, finish: finish);

/// A stand-in server: what each path answers, and what was sent to it.
class FakeWebServer {
  MyDay today = MyDay(date: DateTime.utc(2026, 11, 2), firstDay: false, scheduledStart: '08:00', scheduledFinish: '16:30', breakMinutes: 30);
  MyActivity activity = MyActivity(enabled: true, projects: [towers, workshop, warehouse], companies: const [almeco]);
  List<MyPeriodDay> days = [];
  String? qr = 'employee-qr';
  bool offline = false;
  String? refusePassword;
  final posts = <String, List<Map<String, Object?>>>{};

  http.Client get client => MockClient((request) async {
    if (offline) throw http.ClientException('offline');
    final path = request.url.path;
    if (request.method == 'POST') {
      posts.putIfAbsent(path, () => []).add(jsonDecode(request.body) as Map<String, Object?>);
    }
    return switch ((request.method, path)) {
      ('GET', '/me') => _json({'firstName': 'Disan', 'lastName': 'Ssebowa', 'code': 'SBW', 'companies': ['Almeco']}),
      ('GET', '/me/today') => _json(today.toJson()),
      ('GET', '/me/activity') || ('POST', '/me/activity') => _json(activity.toJson()),
      ('GET', '/me/period') => _json(
        MyPeriod(from: DateTime.utc(2026, 11), to: DateTime.utc(2026, 11, 30), days: days).toJson(),
      ),
      ('GET', '/me/terminal-qr') => qr == null ? _error(404, 'not_found') : _json({'qrCode': qr}),
      ('POST', '/me/time-registrations') => _json(
        RegisteredTime(boundary: RegistrationBoundary.finish, actualId: 9, actualAt: DateTime.utc(2026, 11, 4, 15)).toJson(),
        status: 201,
      ),
      ('POST', '/auth/sign-in') => _session(),
      ('POST', '/me/password') => refusePassword == null ? _session() : _error(400, refusePassword!),
      ('GET', '/languages') => _json({'languages': <Object>[]}),
      ('GET', '/me/language') => _json({'languageCode': null}),
      _ => _error(404, 'not_found'),
    };
  });

  static http.Response _session() => _json({
    'session': {'accessToken': 'token', 'expiresAt': '2099-01-01T00:00:00Z'},
    'account': {'firstName': 'Disan', 'lastName': 'Ssebowa', 'code': 'SBW', 'companies': ['Almeco']},
  });

  static http.Response _json(Object body, {int status = 200}) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

  static http.Response _error(int status, String code) => _json({
    'error': {'code': code, 'message': 'x'},
  }, status: status);
}

/// The real session and API clients, against [FakeWebServer].
class Harness {
  Harness() {
    final transport = ApiTransport(baseUri: Uri.parse('http://test/'), httpClient: server.client, accessToken: () => session.token);
    me = MeApi(transport);
    session = WebSession(auth: AuthApi(transport), me: me, store: store, clock: () => now);
    services = WebServices(
      session: session,
      times: TimeRegistrationsApi(transport),
      activity: ActivityApi(transport),
      me: me,
      languages: LanguagesApi(transport),
    );
    translations = TranslationService(LanguagesApi(transport));
  }

  final server = FakeWebServer();
  final store = MemorySessionStore();
  DateTime now = DateTime(2026, 11, 2, 12, 18);
  late final MeApi me;
  late final WebSession session;
  late final WebServices services;
  late final TranslationService translations;

  Future<void> signedIn() async {
    store.values
      ..['jitan.employee.token'] = 'token'
      ..['jitan.employee.expiresAt'] = '2099-01-01T00:00:00Z';
    await session.restore();
  }

  /// [page] alone, as the shell shows it.
  Future<void> show(WidgetTester tester, Widget page, {Size size = const Size(1440, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: MaterialApp(theme: JitanTheme.web(), home: Scaffold(body: page)),
      ),
    );
    await tester.pumpAndSettle();
  }
}

// LOCAL DEVELOPMENT ONLY: fills the local database with realistic sample data,
// so every HR page can be judged with real-looking numbers (product owner,
// 2026-11-11: realistic names, no "[DEV]" prefix, on the local database only).
//
//   python -I ../../dev/local-db/with_local_db.py dart run tool/sample_data.dart
//
// The API must be running on http://127.0.0.1:8080 (it signs in as HCL).
// Refuses unless JITAN_ENV is development and the database is on this
// computer (127.0.0.1 / localhost): it can never touch IT's database.
// Runs once: it stops when registrations already exist.
//
// Everything goes through Jitan's own code, so it is stored as real use would
// store it: employees, groups, schedules, places and projects through the API
// (audited), and four weeks of starts, finishes, project switches and trips
// through the same services the phone uses (actual and rounded rows, audit).

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:jitan_api/src/activities/activity_repository.dart';
import 'package:jitan_api/src/activities/activity_service.dart';
import 'package:jitan_api/src/activities/trip_kilometres.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/config/app_config.dart';
import 'package:jitan_api/src/config/config_sources.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/locations/location_repository.dart';
import 'package:jitan_api/src/projects/project_repository.dart';
import 'package:jitan_api/src/routing/driving_distance.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_api/src/time_records/my_day_service.dart';
import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_api/src/time_records/time_record_service.dart';
import 'package:jitan_api/src/time_records/week_plans.dart';
import 'package:jitan_api/src/time_registration/registration_rounding.dart';
import 'package:jitan_api/src/time_registration/time_registration_write_repository.dart';
import 'package:jitan_api/src/time_registration/time_registration_write_service.dart';
import 'package:jitan_api/src/time_registration/workplace_clock.dart';
import 'package:jitan_models/jitan_models.dart';

final _api = Uri.parse('http://127.0.0.1:8080/');
final _random = Random(20261111);
const _days = 28;

/// The moment the services believe it is, so past days are written as they
/// happened.
var _now = DateTime.now().toUtc();

Future<void> main() async {
  final config = AppConfig.fromSources(ConfigSources.load(Platform.environment));
  if (config.environment.name != 'development') return _refuse('JITAN_ENV must be development.');
  if (!{'127.0.0.1', 'localhost', '::1'}.contains(config.database.host)) {
    return _refuse('the database is not on this computer (${config.database.host}).');
  }
  final db = Database.connect(config.database, maxConnections: 2);
  try {
    final existing = await db.query('SELECT COUNT(*) AS n FROM tblTimeReg');
    if (existing.single.readInt('n') > 0) return _refuse('registrations already exist; rebuild the local database first.');
    await _fill(db);
  } finally {
    await db.close();
  }
}

void _refuse(String why) {
  stderr.writeln('Refusing to run: $why');
  exitCode = 78;
}

late String _token;

Future<Object?> _call(String method, String path, [Object? body]) async {
  final request = http.Request(method, _api.resolve(path))
    ..headers['content-type'] = 'application/json'
    ..headers['authorization'] = 'Bearer $_token';
  if (body != null) request.body = jsonEncode(body);
  final response = await http.Response.fromStream(await request.send());
  if (response.statusCode >= 300) throw StateError('$method $path → ${response.statusCode}: ${response.body}');
  return response.body.isEmpty ? null : jsonDecode(response.body);
}

/// One employee to add: first name, last name, code, company, blue collar.
typedef _Person = (String, String, String, String, bool);

const _people = <_Person>[
  ('Lotte', 'Janssens', 'LJA', 'Almeco', false),
  ('Pieter', 'Wouters', 'PWO', 'Almeco', true),
  ('Bram', 'Goossens', 'BGO', 'Almeco', true),
  ('Jens', 'Mertens', 'JME', 'Almeco', true),
  ('Ruben', 'Willems', 'RWI', 'Almeco', true),
  ('Sofie', 'Claeys', 'SCL', 'Almeco', false),
  ('Wout', 'Jacobs', 'WJA', 'Almeco', true),
  ('Arne', 'Vandenberghe', 'AVB', 'Almeco', true),
  ('Elke', 'Desmet', 'EDE', 'Almeco', false),
  ('Tom', 'Dubois', 'TDU', 'Almeco', true),
  ('Nicolas', 'Lambert', 'NLA', 'Almeco', true),
  ('Julie', 'Dupont', 'JDU', 'PCA', false),
  ('Maxime', 'Leroy', 'MLE', 'PCA', true),
  ('Thibault', 'Martin', 'TMA', 'PCA', true),
  ('Charlotte', 'Simon', 'CSI', 'PCA', false),
  ('Yannick', 'Lemaire', 'YLE', 'PCA', true),
  ('Dries', 'Smets', 'DSM', 'PCA', true),
  ('Ilse', 'Van Damme', 'IVD', 'Akwa Plus', false),
  ('Koen', 'Hermans', 'KHE', 'Akwa Plus', true),
  ('Stijn', 'Michiels', 'SMI', 'Akwa Plus', true),
  ('Gilles', 'Renard', 'GRE', 'Akwa Plus', true),
  ('Nathalie', 'Maes', 'NMA', 'Akwa Plus', false),
];

/// Not set up yet: the onboarding QR hasn't been scanned.
const _notSetUp = {'NLA', 'DSM', 'NMA'};

Future<void> _fill(Database db) async {
  // Sign in as HR, as a person would.
  final signIn = await http.post(
    _api.resolve('auth/sign-in'),
    headers: {'content-type': 'application/json'},
    body: jsonEncode(const SignInRequest(code: 'HCL', password: 'Hanne-Local-Dev-1', deviceId: '7d1f3c2a-5b6e-4f80-9a1b-2c3d4e5f6a7b').toJson()),
  );
  if (signIn.statusCode != 200) throw StateError('Sign-in failed (${signIn.statusCode}); is the API running?');
  _token = SessionResponse.fromJson(jsonDecode(signIn.body) as Map<String, Object?>).session.accessToken;

  // Companies come from IT; here they are added the way IT would.
  for (final name in ['Akwa Plus']) {
    final found = await db.query('SELECT companyID FROM tblCompany WHERE companyName = :n', {'n': name});
    if (found.isEmpty) {
      await db.execute('INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)', {'n': name});
    }
  }
  final companies = {
    for (final row in await db.query('SELECT companyID, companyName FROM tblCompany')) row.readString('companyName'): row.readInt('companyID'),
  };
  final groups = {
    for (final row in await db.query('SELECT groupID, groupName FROM tblGroup')) row.readString('groupName'): row.readInt('groupID'),
  };
  final white = groups['White collar']!, blue = groups['Blue collar']!;
  stdout.writeln('Companies: ${companies.keys.join(', ')}');

  // Places.
  Future<int?> existing(String name) async => (await db.query(
    'SELECT addressID FROM tblAddress WHERE addressLogicalName = :n AND addressMFD = 0',
    {'n': name},
  )).firstOrNull?.readInt('addressID');

  Future<int> place(String name, String street, String number, String zip, String city, double lat, double lng) async {
    if (await existing(name) case final id?) return id;
    final json = await _call('POST', 'locations', {
      'name': name,
      'street': street,
      'number': number,
      'zipcode': zip,
      'city': city,
      'point': GeoPoint(latitude: lat, longitude: lng).toJson(),
      'radiusMeters': 100,
    }) as Map<String, Object?>;
    return json['id']! as int;
  }

  final almeco = await place('Almeco workshop', 'Rue de la Royenne', '70', '7700', 'Mouscron', 50.7446, 3.2149);
  final pcaOffice = await place('PCA office', 'Doorniksesteenweg', '214', '8500', 'Kortrijk', 50.8098, 3.2627);
  final akwa = await place('Akwa Plus depot', 'Industriepark', '12', '8790', 'Waregem', 50.8885, 3.4269);
  stdout.writeln('Places: 3');

  // Projects: client sites with their own area, and internal work at Almeco.
  Future<int> project(String sap, String name, {(String, String, String, String, double, double)? site, int? workshop}) async {
    if (await existing('$sap $name') case final id?) return id;
    final json = await _call('POST', 'projects', {
      'sapNumber': sap,
      'name': name,
      if (site case (final street, final number, final zip, final city, final lat, final lng))
        'site': {
          'name': '$sap $name',
          'street': street,
          'number': number,
          'zipcode': zip,
          'city': city,
          'point': GeoPoint(latitude: lat, longitude: lng).toJson(),
          'radiusMeters': 150,
        },
      'workshopId': ?workshop,
    }) as Map<String, Object?>;
    return json['id']! as int;
  }

  final clientSites = [
    await project('P-1042', 'Office refurbishment', site: ('Grand-Place', '1', '7700', 'Mouscron', 50.7437, 3.2140)),
    await project('P-1057', 'Cooling towers', site: ('Rue de la Station', '45', '4480', 'Engis', 50.5813, 5.4053)),
    await project('P-1063', 'Warehouse upgrade', site: ('Kortrijkstraat', '300', '8500', 'Kortrijk', 50.8280, 3.2649)),
    await project('P-1071', 'Roof repairs', site: ('Rue Royale', '18', '7500', 'Tournai', 50.6056, 3.3889)),
  ];
  final internal = await project('P-0990', 'Clean the workshop', workshop: almeco);
  stdout.writeln('Projects: ${clientSites.length + 1}');

  // Employees.
  final ids = <String, int>{};
  for (final (first, last, code, company, isBlue) in _people) {
    final found = await db.query('SELECT userID FROM tblUser WHERE userCode = :c', {'c': code});
    if (found.isNotEmpty) {
      ids[code] = found.single.readInt('userID');
      continue;
    }
    final json = await _call('POST', 'companies/${companies[company]}/employees', CreateEmployeeRequest(
      firstName: first,
      lastName: last,
      code: code,
      companyIds: [companies[company]!],
      groupIds: [isBlue ? blue : white],
    ).toJson()) as Map<String, Object?>;
    ids[code] = json['id']! as int;
  }
  // Set up = a password set on their phone (onboarding); here the seed's hash.
  final hash = (await db.query("SELECT userPassword FROM tblUser WHERE userCode = 'KDV'")).single.readString('userPassword');
  for (final MapEntry(key: code, value: id) in ids.entries) {
    if (!_notSetUp.contains(code)) {
      await db.execute('UPDATE tblUser SET userPassword = :p WHERE userID = :u', {'p': hash, 'u': id});
    }
  }
  stdout.writeln('Employees: ${ids.length} added');

  // Schedules per group: given to every member.
  final options = ScheduleOptions.fromJson((await _call('GET', 'schedules/options'))! as Map<String, Object?>);
  final weekdays = options.days.take(5).map((d) => d.id).toList();
  Future<void> schedule(int groupId, String start, String finish) => _call('PUT', 'schedules/groups/$groupId', SetGroupScheduleRequest(
    workHours: SetWorkHoursRequest(
      days: [for (final day in weekdays) WorkHoursDay(dayId: day, start: start, finish: finish)],
      arrivalToleranceMinutes: 5,
      leavingToleranceMinutes: 5,
      startRounding: const ScheduleRounding(intervalMinutes: 15, roundUp: true),
      finishRounding: const ScheduleRounding(intervalMinutes: 15, roundUp: false),
    ),
    breakMinutes: 30,
  ).toJson());
  await schedule(white, '08:30', '17:00');
  await schedule(blue, '07:30', '16:00');
  stdout.writeln('Schedules: White collar 08:30–17:00, Blue collar 07:30–16:00, 30 min break');

  // Who registers: active, set up, with a schedule.
  final workers = [
    for (final row in await db.query(
      'SELECT u.userID, MIN(u.userCode) AS userCode, MIN(g.groupID) AS groupID, MIN(uc.companyID) AS companyID FROM tblUser u '
      'JOIN tblUserGroup g ON g.userID = u.userID AND g.userGroupActive = 1 AND g.userGroupMFD = 0 '
      'JOIN tblUserCompany uc ON uc.userID = u.userID AND uc.userCompanyActive = 1 AND uc.userCompanyMFD = 0 '
      'WHERE u.userActive = 1 AND u.userMFD = 0 AND u.userPassword IS NOT NULL AND u.userKioskMode = 0 '
      'GROUP BY u.userID',
    ))
      (
        id: row.readInt('userID'),
        code: row.readString('userCode'),
        blue: row.readInt('groupID') == blue,
        home: switch (row.readInt('companyID')) {
          final c when c == companies['PCA'] => pcaOffice,
          final c when c == companies['Akwa Plus'] => akwa,
          _ => almeco,
        },
      ),
  ];

  await _registrations(db, workers, clientSites: clientSites, internal: internal);
}

typedef _Worker = ({int id, String code, bool blue, int home});

Future<void> _registrations(Database db, List<_Worker> workers, {required List<int> clientSites, required int internal}) async {
  final clock = WorkplaceClock('Europe/Brussels');
  final schedules = ScheduleRepository(db);
  final records = TimeRecordRepository(db);
  DateTime now() => _now;
  final days = TimeRecordService(
    records: records,
    employees: EmployeeRepository(db),
    companies: CompanyRepository(db),
    clock: clock,
    schedules: schedules,
    rounding: RegistrationRounding(schedules),
    now: now,
  );
  final activities = ActivityService(
    activities: const ActivityRepository(),
    projects: const ProjectRepository(),
    writes: const TimeRegistrationWriteRepository(),
    myDay: MyDayService(days: days, records: records, plans: WeekPlans(schedules), clock: clock, now: now),
    locations: const LocationRepository(),
    kilometres: TripKilometres(
      activities: const ActivityRepository(),
      locations: const LocationRepository(),
      distance: const NoDrivingDistance(),
      executor: db,
      clock: clock,
    ),
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
    clock: clock,
    now: now,
  );
  final writes = TimeRegistrationWriteService(
    transactions: db,
    rounding: RegistrationRounding(schedules),
    clock: clock,
    onDayStart: activities.dayStarted,
    now: now,
  );

  final today = clock.wallClockOf(DateTime.now().toUtc());
  DateTime at(DateTime day, int minutes) => clock.utcOf(DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60, _random.nextInt(60)));
  int around(int minutes, int early, int late) => minutes - early + _random.nextInt(early + late + 1);

  Future<void> register(int user, RegistrationBoundary boundary, DateTime moment, {int? place, String? reason}) async {
    _now = moment.add(const Duration(minutes: 1));
    final geofence = place != null && reason == null;
    await writes.register(
      user,
      RegisterTimeRequest(
        boundary: boundary,
        method: geofence ? TimeRegistrationMethod.geofence : TimeRegistrationMethod.manual,
        entry: reason == null ? RegistrationEntry.now : RegistrationEntry.corrected,
        at: moment,
        addressId: geofence ? place : null,
        reason: reason,
      ),
    );
  }

  Future<void> switchTo(int user, ActivityKind kind, DateTime moment, int? project) async {
    _now = moment.add(const Duration(minutes: 1));
    await activities.switchTo(user, SwitchActivityRequest(kind: kind, at: moment, projectId: project));
  }

  var count = 0;
  for (var back = _days; back >= 1; back--) {
    final day = DateTime(today.year, today.month, today.day - back);
    if (day.weekday > 5) continue;
    for (final (i, w) in workers.indexed) {
      final roll = _random.nextInt(100);
      if (roll < 3) continue; // a day off nobody registered
      final start = w.blue ? 7 * 60 + 30 : 8 * 60 + 30;
      final finish = w.blue ? 16 * 60 : 17 * 60;
      final arrives = at(day, around(start, 14, roll < 12 ? 22 : 6));
      final geofence = _random.nextInt(100) < 70;
      await register(w.id, RegistrationBoundary.start, arrives, place: geofence ? w.home : null);

      if (w.blue) {
        // Most days on a client project: drive there, work, drive back.
        final site = clientSites[(i + back ~/ 5) % clientSites.length];
        if (_random.nextInt(100) < 80) {
          final leaves = arrives.add(Duration(minutes: 10 + _random.nextInt(15)));
          await switchTo(w.id, ActivityKind.transport, leaves, site);
          final there = leaves.add(Duration(minutes: 25 + _random.nextInt(35)));
          await switchTo(w.id, ActivityKind.clientOnSite, there, site);
          final home = at(day, finish - 40 - _random.nextInt(20));
          await switchTo(w.id, ActivityKind.transport, home, site);
        } else {
          await switchTo(w.id, ActivityKind.internal, arrives.add(const Duration(minutes: 5)), internal);
        }
      }

      if (roll >= 3 && roll < 5 && back > 1) {
        count++;
        continue; // forgot to finish: a day to review
      }
      final leaves = at(day, around(finish, roll < 15 ? 25 : 4, 28));
      if (roll >= 5 && roll < 7) {
        // A correction waiting for HR.
        await register(w.id, RegistrationBoundary.finish, leaves, reason: 'Forgot to finish on the app; left at this time.');
      } else {
        await register(w.id, RegistrationBoundary.finish, leaves, place: _random.nextBool() ? w.home : null);
      }
      count++;
    }
    stdout.writeln('${day.year}-${day.month}-${day.day}: done');
  }
  stdout.writeln('Working days registered: $count');
}

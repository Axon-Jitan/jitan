import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

Future<Response> _post(TestApp app, String path, Map<String, Object?> body) => app.post(path, jsonEncode(body));

Future<Response> _put(TestApp app, String path, Map<String, Object?> body) => app.put(path, jsonEncode(body));

EmployeeSummary _employee(int id, String code) => EmployeeSummary(
  id: id,
  firstName: 'First',
  lastName: code,
  code: code,
  groups: const [],
  isActive: true,
  isActivated: true,
);

const _location = LocationRequest(
  name: 'Prayon site',
  street: 'Rue Joseph Wauters',
  point: GeoPoint(latitude: 50.59, longitude: 5.65),
  radiusMeters: 50,
);

ProjectRequest _client({int? addressId, String name = 'Cooling towers', String start = '2026-10-19', String? end}) =>
    ProjectRequest(name: name, typeId: 1, statusId: 1, startDate: start, endDate: end, addressId: addressId);

const _internal = ProjectRequest(name: 'Clean the workshop', typeId: 2, statusId: 2, startDate: '2026-10-19');

Future<(TestApp, int)> _app() async {
  final app = TestApp();
  app.companies.existingIds = {7, 8};
  app.companies.companies = [company(7, 'Almeco'), company(8, 'PCA')];
  app.employees.byCompany = {
    7: [_employee(11, 'AAA'), _employee(12, 'BBB')],
    8: [_employee(21, 'OCO')],
  };
  final response = await _post(app, '/locations', _location.toJson());
  return (app, (await jsonBody(response))['id']! as int);
}

Future<int> _add(TestApp app, ProjectRequest request, {int company = 7}) async {
  final response = await _post(app, '/companies/$company/projects', request.toJson());
  expect(response.statusCode, 201);
  return (await jsonBody(response))['id']! as int;
}

void main() {
  test('the form offers the types and statuses, and says which type needs an address', () async {
    final (app, _) = await _app();

    final options = ProjectOptions.fromJson(await jsonBody(await app.get('/project-options')));

    expect(options.types.map((t) => t.name), ['Client', 'Internal']);
    expect(options.addressTypeIds, [1]);
  });

  test('adds a client project with its address, audited', () async {
    final (app, address) = await _app();

    final response = await _post(app, '/companies/7/projects', _client(addressId: address).toJson());

    expect(response.statusCode, 201);
    final project = ProjectDetails.fromJson(await jsonBody(response));
    expect((project.summary.name, project.summary.companyName, project.addressId), ('Cooling towers', 'Almeco', address));
    expect(app.audit.events.last.type, AuditEventType.projectCreated);
    expect(app.audit.events.last.references[EventLogReference.project], project.summary.id);
  });

  test('a client project needs an address; an internal one never keeps one', () async {
    final (app, address) = await _app();

    expect((await _post(app, '/companies/7/projects', _client().toJson())).statusCode, 400);
    final id = await _add(
      app,
      ProjectRequest(name: 'Stock', typeId: 2, statusId: 1, startDate: '2026-10-19', addressId: address),
    );

    final details = ProjectDetails.fromJson(await jsonBody(await app.get('/companies/7/projects/$id')));
    expect(details.addressId, isNull);
  });

  test('a deactivated location cannot be the client address', () async {
    final (app, address) = await _app();
    await _post(app, '/locations/$address/deactivate', const {});

    expect((await _post(app, '/companies/7/projects', _client(addressId: address).toJson())).statusCode, 400);
  });

  group('checks', () {
    for (final (what, request) in [
      ('no name', _client(addressId: 1, name: '  ')),
      ('a long name', _client(addressId: 1, name: 'x' * 151)),
      ('no date', _client(addressId: 1, start: '')),
      ('an impossible date', _client(addressId: 1, start: '2026-02-30')),
      ('an end before the start', _client(addressId: 1, end: '2026-10-18')),
      ('an unknown type', const ProjectRequest(name: 'x', typeId: 9, statusId: 1, startDate: '2026-10-19')),
      ('an unknown status', const ProjectRequest(name: 'x', typeId: 2, statusId: 9, startDate: '2026-10-19')),
    ]) {
      test('$what → 400, nothing stored', () async {
        final (app, _) = await _app();

        expect((await _post(app, '/companies/7/projects', request.toJson())).statusCode, 400);
        expect(app.projects.projects, isEmpty);
      });
    }

    test('a hostile name is stored as text', () async {
      final (app, _) = await _app();
      const hostile = "x'); DROP TABLE tblProject; --";

      final id = await _add(app, const ProjectRequest(name: hostile, typeId: 2, statusId: 1, startDate: '2026-10-19'));

      expect(app.projects.projects[id]!.request.name, hostile);
    });
  });

  test('edits a project and audits it', () async {
    final (app, _) = await _app();
    final id = await _add(app, _internal);

    final response = await _put(
        app,
      '/companies/7/projects/$id',
      const ProjectRequest(name: 'Renamed', typeId: 2, statusId: 1, startDate: '2026-10-20').toJson(),
    );

    expect(response.statusCode, 200);
    expect(ProjectDetails.fromJson(await jsonBody(response)).summary.name, 'Renamed');
    expect(app.audit.events.last.type, AuditEventType.projectChanged);
  });

  group('company isolation', () {
    test('another company cannot read or change a project', () async {
      final (app, _) = await _app();
      final id = await _add(app, _internal);

      expect((await app.get('/companies/8/projects/$id')).statusCode, 404);
      expect((await _put(app, '/companies/8/projects/$id', _internal.toJson())).statusCode, 404);
      expect((await _put(app, '/companies/8/projects/$id/employees', const ProjectEmployeesRequest(employeeIds: [21]).toJson())).statusCode, 404);
    });

    test('the list shows only companies the viewer may see', () async {
      final (app, _) = await _app();
      await _add(app, _internal);
      await _add(app, const ProjectRequest(name: 'PCA work', typeId: 2, statusId: 1, startDate: '2026-10-19'), company: 8);
      app.permissions.deniedCompanies = {7};

      final list = ProjectListResponse.fromJson(await jsonBody(await app.get('/projects')));

      expect(list.projects.map((p) => p.name), ['PCA work']);
    });

    test('adding needs the right in that company', () async {
      final (app, _) = await _app();
      app.permissions.deniedCompanies = {7};

      expect((await _post(app, '/companies/7/projects', _internal.toJson())).statusCode, 403);
      expect(app.permissions.checked.map((c) => c.$2), contains(Permission.manageProjects));
    });

    test('a session is required', () async {
      expect((await TestApp(devUserId: null).get('/projects')).statusCode, 401);
      expect((await TestApp(devUserId: null).get('/project-options')).statusCode, 401);
    });
  });

  group('assignments', () {
    Future<ProjectDetails> assign(TestApp app, int id, List<int> employees) async {
      final response = await _put(
        app,
        '/companies/7/projects/$id/employees',
        ProjectEmployeesRequest(employeeIds: employees).toJson(),
      );
      expect(response.statusCode, 200);
      return ProjectDetails.fromJson(await jsonBody(response));
    }

    test('saves the team, audits each change, and counts it', () async {
      final (app, _) = await _app();
      final id = await _add(app, _internal);

      final project = await assign(app, id, [11, 12]);

      expect(project.summary.teamSize, 2);
      expect(app.audit.events.where((e) => e.type == AuditEventType.projectEmployeeAssigned), hasLength(2));
    });

    test('removing is soft; coming back reactivates the same row', () async {
      final (app, _) = await _app();
      final id = await _add(app, _internal);
      await assign(app, id, [11, 12]);
      final first = app.projects.linksRows[(12, id)]!.id;

      expect((await assign(app, id, [11])).summary.teamSize, 1);
      expect(app.projects.linksRows[(12, id)]!.current, isFalse);
      expect(app.audit.events.last.type, AuditEventType.projectEmployeeUnassigned);

      await assign(app, id, [11, 12]);
      expect(app.projects.linksRows[(12, id)], (id: first, current: true));
    });

    test('saving the same team changes nothing and audits nothing', () async {
      final (app, _) = await _app();
      final id = await _add(app, _internal);
      await assign(app, id, [11]);
      final events = app.audit.events.length;

      await assign(app, id, [11]);

      expect(app.audit.events, hasLength(events));
    });

    test("someone from another company can't be assigned", () async {
      final (app, _) = await _app();
      final id = await _add(app, _internal);

      final response = await _put(
        app,
        '/companies/7/projects/$id/employees',
        const ProjectEmployeesRequest(employeeIds: [21]).toJson(),
      );

      expect(response.statusCode, 400);
      expect(app.projects.linksRows, isEmpty);
    });
  });
}

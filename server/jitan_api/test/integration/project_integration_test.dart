@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/locations/location_repository.dart';
import 'package:jitan_api/src/projects/project_repository.dart';
import 'package:jitan_api/src/projects/project_service.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// PROPOSAL (docs/database/PROPOSED_TABLES.md): projects against the local
/// database, where the proposed tables exist. Skipped where they do not, e.g.
/// IT's database. The tests run in order.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  late bool hasTables;
  late ProjectService projects;
  late ProjectOptions options;
  late int company;
  late int actor;
  late int worker;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final prefix = '[DEV-TEST] $stamp';
  var created = 0;

  ProjectRequest request(String name) => ProjectRequest(
    name: '$prefix $name',
    typeId: options.types.firstWhere((t) => t.name == 'Internal').id,
    statusId: options.statuses.first.id,
    startDate: '2026-10-19',
    endDate: '2026-12-31',
    reference: 'PRJ-1',
    description: 'Notes',
  );

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 2);
    hasTables = (await db.query(
      "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tblProject'",
    )).isNotEmpty;
    if (!hasTables) return;
    final companies = CompanyRepository(db);
    projects = ProjectService(
      projects: const ProjectRepository(),
      companies: companies,
      employees: EmployeeRepository(db),
      locations: const LocationRepository(),
      audit: const AuditLogRepository(),
      transactions: db,
      executor: db,
    );
    options = await projects.options();
    company = (await db.execute(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:n, 1, 0)',
      {'n': '$prefix company'},
    )).lastInsertId;
    Future<int> user(String code) async {
      final id = (await db.execute(
        'INSERT INTO tblUser (userName, userSurname, userCode, userActive, userMFD) VALUES (:n, :s, :c, 1, 0)',
        {'n': 'Test', 's': code, 'c': '$stamp$code'},
      )).lastInsertId;
      await db.execute(
        'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
        {'u': id, 'c': company},
      );
      return id;
    }

    actor = await user('A');
    worker = await user('W');
  });

  tearDownAll(() async {
    if (hasTables) {
      await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID IN (SELECT eventLogID FROM tblEventLog WHERE companyID = :c)', {'c': company});
      await db.execute('DELETE FROM tblEventLog WHERE companyID = :c', {'c': company});
      await db.execute('DELETE up FROM tblUserProject up JOIN tblProject p ON p.projectID = up.projectID WHERE p.companyID = :c', {'c': company});
      await db.execute('DELETE FROM tblProject WHERE companyID = :c', {'c': company});
      await db.execute('DELETE FROM tblUserCompany WHERE companyID = :c', {'c': company});
      await db.execute('DELETE FROM tblUser WHERE userID IN (:a, :w)', {'a': actor, 'w': worker});
      await db.execute('DELETE FROM tblCompany WHERE companyID = :c', {'c': company});
    }
    await db.close();
  });

  test('reads the lookups from the database', () async {
    if (!hasTables) return markTestSkipped('The proposed tables are not here.');

    expect(options.types.map((t) => t.name), containsAll(['Client', 'Internal']));
    expect(options.statuses.map((s) => s.name), ['Planned', 'Active', 'Completed']);
    expect(options.addressTypeIds, hasLength(1));
  });

  test('adds, reads, lists and changes a project, audited', () async {
    if (!hasTables) return markTestSkipped('The proposed tables are not here.');

    final project = await projects.create(actor, company, request('Clean'));
    created = project.summary.id;

    expect(project.summary.reference, 'PRJ-1');
    expect(project.startDate, DateTime.utc(2026, 10, 19));
    expect(project.endDate, DateTime.utc(2026, 12, 31));
    expect(project.description, 'Notes');
    final listed = await projects.list((id) async => id == company);
    expect(listed.map((p) => p.id), [created]);

    final changed = await projects.update(actor, company, created, request('Renamed'));
    expect(changed.summary.name, '$prefix Renamed');
    final audit = await db.query('SELECT COUNT(*) AS n FROM tblEventLog WHERE projectID = :p AND userIDInit = :a', {
      'p': created,
      'a': actor,
    });
    expect(audit.single.readInt('n'), 2);
  });

  test('assigns, removes softly and brings back the same row', () async {
    if (!hasTables) return markTestSkipped('The proposed tables are not here.');

    final assigned = await projects.assign(actor, company, created, ProjectEmployeesRequest(employeeIds: [worker]));
    expect(assigned.summary.teamSize, 1);
    expect(assigned.employees.single.id, worker);

    final removed = await projects.assign(actor, company, created, const ProjectEmployeesRequest(employeeIds: []));
    expect(removed.summary.teamSize, 0);
    await projects.assign(actor, company, created, ProjectEmployeesRequest(employeeIds: [worker]));

    final rows = await db.query('SELECT userProjectActive, userProjectMFD FROM tblUserProject WHERE projectID = :p', {'p': created});
    expect(rows, hasLength(1));
    expect((rows.single.readBool('userProjectActive'), rows.single.readBool('userProjectMFD')), (true, false));
  });

  test('a hostile name stays text, and another company finds nothing', () async {
    if (!hasTables) return markTestSkipped('The proposed tables are not here.');

    final hostile = ProjectRequest(
      name: "$prefix '); DROP TABLE tblProject; --",
      typeId: request('x').typeId,
      statusId: request('x').statusId,
      startDate: '2026-10-19',
    );
    final project = await projects.create(actor, company, hostile);

    expect(project.summary.name, hostile.name);
    expect(await const ProjectRepository().find(db, company + 1, project.summary.id), isNull);
  });
}

import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/database/database_exception.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _check = '/companies/7/employees/import/check';
const _import = '/companies/7/employees/import';

TestApp _app({bool allow = true}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9}, allowPermissions: allow);
  app.companies.existingIds = {7};
  app.groups.groups = const [
    GroupSummary(id: 3, name: 'White collar'),
    GroupSummary(id: 4, name: 'Blue collar'),
    GroupSummary(id: 5, name: 'Drivers'),
    GroupSummary(id: 6, name: 'Drivers'),
  ];
  return app;
}

EmployeeImportRow _row(
  int row, {
  String first = 'Anna',
  String last = 'Peeters',
  String? code,
  String? phone,
  String? email,
  List<String> groups = const [],
}) => EmployeeImportRow(
  row: row,
  firstName: first,
  lastName: last,
  code: code ?? 'C$row',
  phone: phone,
  email: email,
  groups: groups,
);

String _body(List<EmployeeImportRow> rows) => jsonEncode(EmployeeImportRequest(rows: rows).toJson());

Future<List<EmployeeImportProblem>> _problems(TestApp app, List<EmployeeImportRow> rows) async {
  final response = await app.post(_check, _body(rows));
  expect(response.statusCode, 200);
  return EmployeeImportCheck.fromJson(await jsonBody(response)).problems;
}

void main() {
  group('POST …/employees/import/check', () {
    test('reports one problem per row, the first found; ready rows are not listed', () async {
      final app = _app()..employees.takenCodes = {'SBW'};

      final problems = await _problems(app, [
        _row(2, groups: [' blue COLLAR ']),
        _row(3, first: ' '),
        _row(4, last: ''),
        _row(5, code: '  '),
        _row(6, code: 'sbw'),
        _row(7, code: 'C2'),
        _row(8, email: 'not-an-email'),
        _row(9, groups: ['Cleaners']),
        _row(10, groups: ['Drivers']),
        _row(11, first: 'x' * (CreateEmployeeRequest.maxFirstNameLength + 1)),
        _row(12, phone: '1' * (CreateEmployeeRequest.maxPhoneLength + 1)),
        _row(13, first: '', last: ''),
      ]);

      expect([for (final p in problems) (p.row, p.kind, p.detail)], [
        (3, EmployeeImportProblemKind.firstNameMissing, null),
        (4, EmployeeImportProblemKind.lastNameMissing, null),
        (5, EmployeeImportProblemKind.codeMissing, null),
        (6, EmployeeImportProblemKind.codeUsed, 'sbw'),
        (7, EmployeeImportProblemKind.codeRepeated, '2'),
        (8, EmployeeImportProblemKind.emailInvalid, null),
        (9, EmployeeImportProblemKind.groupUnknown, 'Cleaners'),
        (10, EmployeeImportProblemKind.groupAmbiguous, 'Drivers'),
        (11, EmployeeImportProblemKind.tooLong, EmployeeImportRow.fieldFirstName),
        (12, EmployeeImportProblemKind.tooLong, EmployeeImportRow.fieldPhone),
        (13, EmployeeImportProblemKind.firstNameMissing, null),
      ]);
      expect(app.employees.writes, isEmpty, reason: 'a check writes nothing');
      expect(app.audit.events, isEmpty);
    });

    test('codes repeated in the file compare without regard to case or spaces', () async {
      final problems = await _problems(_app(), [_row(2, code: 'abc'), _row(3, code: ' ABC ')]);

      expect([for (final p in problems) (p.row, p.kind, p.detail)], [(3, EmployeeImportProblemKind.codeRepeated, '2')]);
    });

    test('400 for no rows, too many rows or a repeated row number', () async {
      final app = _app();
      for (final rows in [
        <EmployeeImportRow>[],
        [for (var i = 0; i <= EmployeeImportRequest.maxRows; i++) _row(i + 2)],
        [_row(2), _row(2, code: 'other')],
      ]) {
        final response = await app.post(_check, _body(rows));
        expect(response.statusCode, 400);
        final error = (await jsonBody(response))['error']! as Map<String, Object?>;
        expect(error['field'], EmployeeImportRequest.fieldRows);
      }
    });

    test('400 for a malformed body', () async {
      final response = await _app().post(_check, jsonEncode({'rows': 'nope'}));

      expect(response.statusCode, 400);
    });

    test('404 for an unknown company; 403 without the right', () async {
      expect((await _app().post('/companies/8/employees/import/check', _body([_row(2)]))).statusCode, 404);
      expect((await _app(allow: false).post(_check, _body([_row(2)]))).statusCode, 403);
    });
  });

  group('POST …/employees/import', () {
    test('adds the ready rows in one transaction, each audited as Add employee does; skips the others', () async {
      final app = _app()..employees.takenCodes = {'SBW'};

      final response = await app.post(_import, _body([
        _row(2, code: ' APE ', phone: ' +32 470 ', email: ' anna@example.com ', groups: ['White collar']),
        _row(3, code: 'SBW'),
        _row(4, code: 'BJA', groups: ['Blue collar', 'white collar']),
      ]));

      expect(response.statusCode, 200);
      final result = EmployeeImportResult.fromJson(await jsonBody(response));
      expect(result.added, 2);
      expect([for (final p in result.skipped) (p.row, p.kind)], [(3, EmployeeImportProblemKind.codeUsed)]);
      expect(app.employees.writes, [
        'insertUser APE',
        'addToCompany 100→7',
        'addToGroup 100→3',
        'insertUser BJA',
        'addToCompany 101→7',
        'addToGroup 101→3',
        'addToGroup 101→4',
      ]);
      expect(app.employees.insertedQrCodes, ['QR-1', 'QR-2'], reason: 'a new personal QR per employee');
      expect(app.transactions.outcomes, ['commit'], reason: 'one transaction for the whole file');
      expect([for (final e in app.audit.events) (e.type, e.actorUserId, e.references[EventLogReference.user])], [
        (AuditEventType.employeeCreated, 9, 100),
        (AuditEventType.groupAssigned, 9, 100),
        (AuditEventType.employeeCreated, 9, 101),
        (AuditEventType.groupAssigned, 9, 101),
        (AuditEventType.groupAssigned, 9, 101),
      ]);
    });

    test('nothing ready: adds none, reports every row', () async {
      final app = _app();

      final response = await app.post(_import, _body([_row(2, first: ''), _row(3, last: '')]));

      final result = EmployeeImportResult.fromJson(await jsonBody(response));
      expect(result.added, 0);
      expect(result.skipped, hasLength(2));
      expect(app.employees.writes, isEmpty);
    });

    test('409 and nothing added when a code is taken while importing', () async {
      final app = _app()
        ..employees.insertFailure = const DatabaseQueryException("Duplicate entry 'C2'", errorCode: 1062);

      final response = await app.post(_import, _body([_row(2)]));

      expect(response.statusCode, 409);
      final error = (await jsonBody(response))['error']! as Map<String, Object?>;
      expect(error['code'], ApiErrorCode.duplicateEmployeeCode);
      expect(app.transactions.outcomes, ['rollback']);
    });

    test('403 without the right: nothing is written', () async {
      final app = _app(allow: false);

      expect((await app.post(_import, _body([_row(2)]))).statusCode, 403);
      expect(app.employees.writes, isEmpty);
    });
  });
}

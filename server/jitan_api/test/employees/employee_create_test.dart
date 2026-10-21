import 'dart:convert';

import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/database/database_exception.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/7/employees';

TestApp _app({bool allow = true}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9}, allowPermissions: allow);
  app.companies.existingIds = {7};
  app.groups.groups = const [GroupSummary(id: 3, name: 'White collar')];
  return app;
}

String _body({
  Object? firstName = 'Disan',
  Object? lastName = 'Ssebowa',
  Object? code = 'SBW',
  Object? groupId,
  Object? phone,
  Object? email,
}) => jsonEncode({
  'firstName': firstName,
  'lastName': lastName,
  'code': code,
  'groupIds': [?groupId],
  'phone': phone,
  'email': email,
});

Future<Map<String, Object?>> _error(TestApp app, String body) async {
  final response = await app.post(_path, body);
  return {'status': response.statusCode, ...(await jsonBody(response))['error']! as Map<String, Object?>};
}

void main() {
  group('POST /companies/{id}/employees', () {
    test('201: creates the employee, company link, group link and audit entry in one transaction', () async {
      final app = _app();

      final response = await app.post(
        _path,
        _body(firstName: ' Disan ', code: ' SBW ', groupId: 3, phone: ' +32 470 ', email: ' disan@example.com '),
      );

      expect(response.statusCode, 201);
      expect(await jsonBody(response), containsPair('code', 'SBW'));
      expect(app.employees.writes, ['insertUser SBW', 'addToCompany 100→7', 'addToGroup 100→3']);
      expect(app.employees.lastPhone, '+32 470');
      expect(app.employees.lastEmail, 'disan@example.com');
      expect(app.employees.insertedQrCodes, ['QR-1'], reason: 'a new personal QR per employee');
      expect(app.transactions.outcomes, ['commit']);

      final [created, assigned] = app.audit.events;
      expect(created.type, AuditEventType.employeeCreated);
      expect(created.actorUserId, 9);
      expect(created.references, {
        EventLogReference.user: 100,
        EventLogReference.company: 7,
        EventLogReference.userCompany: 600,
      });
      expect(assigned.type, AuditEventType.groupAssigned);
      expect(assigned.references, {
        EventLogReference.user: 100,
        EventLogReference.group: 3,
        EventLogReference.userGroup: 1000,
      });
    });

    test('without a group: no group link, no group in the audit entry; empty phone stored as NULL', () async {
      final app = _app();

      final response = await app.post(_path, _body(phone: '   '));

      expect(response.statusCode, 201);
      expect(app.employees.writes, ['insertUser SBW', 'addToCompany 100→7']);
      expect(app.employees.lastPhone, isNull);
      expect(app.audit.events.single.references.keys, isNot(contains(EventLogReference.group)));
    });

    test('checks createEmployee for that company before writing anything', () async {
      final app = _app(allow: false);

      final response = await app.post(_path, _body());

      expect(response.statusCode, 403);
      expect(app.permissions.checked, [(9, Permission.createEmployee, 7)]);
      expect(app.employees.writes, isEmpty);
    });

    for (final (field, body) in [
      ('firstName', _body(firstName: '  ')),
      ('lastName', _body(lastName: '')),
      ('code', _body(code: ' ')),
    ]) {
      test('400 validation_failed naming "$field" when it is blank', () async {
        final app = _app();

        final error = await _error(app, body);

        expect(error, containsPair('status', 400));
        expect(error, containsPair('code', 'validation_failed'));
        expect(error, containsPair('field', field));
        expect(app.transactions.outcomes, isEmpty, reason: 'validated before the transaction');
      });
    }

    for (final (field, max, body) in [
      ('firstName', CreateEmployeeRequest.maxFirstNameLength, (String v) => _body(firstName: v)),
      ('lastName', CreateEmployeeRequest.maxLastNameLength, (String v) => _body(lastName: v)),
      ('code', CreateEmployeeRequest.maxCodeLength, (String v) => _body(code: v)),
      ('phone', CreateEmployeeRequest.maxPhoneLength, (String v) => _body(phone: v)),
    ]) {
      test('"$field": $max characters fit; one more is 400 validation_failed before any write', () async {
        final tooLong = await _error(_app(), body('x' * (max + 1)));
        expect(tooLong, containsPair('status', 400));
        expect(tooLong, containsPair('code', 'validation_failed'));
        expect(tooLong, containsPair('field', field));

        final app = _app();
        expect((await app.post(_path, body('x' * max))).statusCode, 201);
      });
    }

    test('lengths count characters as MySQL does: an emoji is one, surrounding spaces none', () async {
      final app = _app();
      final emojiCode = '😀' * CreateEmployeeRequest.maxCodeLength;

      expect((await app.post(_path, _body(code: '  $emojiCode  '))).statusCode, 201);
      final tooLong = await _error(_app(), _body(code: '${emojiCode}x'));
      expect(tooLong, containsPair('field', 'code'));
    });

    test('400 naming groupIds for an unknown or inactive group', () async {
      final app = _app();

      final error = await _error(app, _body(groupId: 99));

      expect(error, containsPair('field', 'groupIds'));
      expect(app.employees.writes, isEmpty);
    });

    test('400 naming email for an address that is not one; nothing written', () async {
      final app = _app();

      final error = await _error(app, _body(email: 'disan.example.com'));

      expect(error, containsPair('field', 'email'));
      expect(app.employees.writes, isEmpty);
    });

    test('400 naming scheduleGroupId for a work schedule outside the employee\'s groups', () async {
      final app = _app();

      final error = await _error(
        app,
        jsonEncode({'firstName': 'A', 'lastName': 'B', 'code': 'C', 'groupIds': [3], 'scheduleGroupId': 4}),
      );

      expect(error, containsPair('field', 'scheduleGroupId'));
      expect(app.employees.writes, isEmpty);
    });

    test('other companies need the right to add employees there too', () async {
      final app = _app(allow: false);

      final response = await app.post(_path, jsonEncode({'firstName': 'A', 'lastName': 'B', 'code': 'C', 'companyIds': [8]}));

      expect(response.statusCode, 403);
      expect(app.employees.writes, isEmpty);
    });

    test('409 duplicate_employee_code naming "code" when the code is taken; rolled back', () async {
      final app = _app()..employees.existingCodes = {'SBW'};

      final error = await _error(app, _body());

      expect(error, containsPair('status', 409));
      expect(error, containsPair('code', 'duplicate_employee_code'));
      expect(error, containsPair('field', 'code'));
      expect(app.employees.writes, isEmpty);
      expect(app.transactions.outcomes, ['rollback']);
    });

    test('409 also when another request takes the code between check and insert', () async {
      final app = _app()
        ..employees.insertFailure = const DatabaseQueryException("Duplicate entry 'SBW'", errorCode: 1062);

      final error = await _error(app, _body());

      expect(error, containsPair('code', 'duplicate_employee_code'));
      expect(app.transactions.outcomes, ['rollback']);
    });

    test('400 when a value is longer than its column (MySQL 1406)', () async {
      final app = _app()..employees.insertFailure = const DatabaseQueryException('Data too long', errorCode: 1406);

      final error = await _error(app, _body());

      expect(error, containsPair('status', 400));
    });

    test('a failing audit write rolls the whole creation back (500)', () async {
      final app = _app()..audit.failWith = const DatabaseQueryException("Unknown column 'x'", errorCode: 1054);

      final response = await app.post(_path, _body());

      expect(response.statusCode, 500);
      expect(app.transactions.outcomes, ['rollback']);
    });

    test('404 for an unknown company', () async {
      final response = await _app().post('/companies/99/employees', _body());

      expect(response.statusCode, 404);
    });

    test('400 for malformed JSON, a non-object body, or a missing required field', () async {
      final app = _app();

      expect((await app.post(_path, '{nope')).statusCode, 400);
      expect((await app.post(_path, '[]')).statusCode, 400);
      expect((await app.post(_path, jsonEncode({'firstName': 'A'}))).statusCode, 400);
      expect(app.employees.writes, isEmpty);
    });
  });
}

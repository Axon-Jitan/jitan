import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

ApiTransport _transport(MockClientHandler handler) =>
    ApiTransport(baseUri: Uri.parse('http://api.test/'), httpClient: MockClient(handler));

void main() {
  test('create POSTs the request as JSON and decodes the created employee', () async {
    late http.Request sent;
    final api = EmployeesApi(_transport((request) async {
      sent = request;
      return http.Response(
        jsonEncode({'id': 5, 'firstName': 'Disan', 'lastName': 'Ssebowa', 'code': 'SBW', 'groups': [], 'isActive': true, 'isActivated': false}),
        201,
      );
    }));

    final created = await api.create(
      7,
      const CreateEmployeeRequest(firstName: 'Disan', lastName: 'Ssebowa', code: 'SBW', groupIds: [3]),
    );

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://api.test/companies/7/employees');
    expect(sent.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), containsPair('groupIds', [3]));
    expect(created.id, 5);
  });

  test('a duplicate code surfaces the error code and field', () async {
    final api = EmployeesApi(_transport((_) async => http.Response(
          jsonEncode({
            'error': {'code': 'duplicate_employee_code', 'message': 'x', 'field': 'code'},
          }),
          409,
        )));

    expect(
      api.create(7, const CreateEmployeeRequest(firstName: 'A', lastName: 'B', code: 'SBW')),
      throwsA(isA<ApiClientException>()
          .having((e) => e.error?.code, 'code', ApiErrorCode.duplicateEmployeeCode)
          .having((e) => e.error?.field, 'field', 'code')),
    );
  });

  test('GroupsApi lists groups', () async {
    final api = GroupsApi(_transport((_) async => http.Response(
          jsonEncode({
            'groups': [
              {'id': 1, 'name': 'White collar'},
            ],
          }),
          200,
        )));

    expect((await api.listGroups()).single.name, 'White collar');
  });
}

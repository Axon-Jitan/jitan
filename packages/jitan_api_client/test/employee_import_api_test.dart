import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

ApiTransport _transport(MockClientHandler handler) =>
    ApiTransport(baseUri: Uri.parse('http://api.test/'), httpClient: MockClient(handler));

const _request = EmployeeImportRequest(
  rows: [
    EmployeeImportRow(row: 2, firstName: 'Anna', lastName: 'Peeters', code: 'APE', groups: ['Blue collar']),
    EmployeeImportRow(row: 3, firstName: 'Dries', lastName: '', code: 'DRI'),
  ],
);

void main() {
  test('checkImport POSTs the rows and decodes the problems', () async {
    late http.Request sent;
    final api = EmployeesApi(_transport((request) async {
      sent = request;
      return http.Response(
        jsonEncode({
          'problems': [
            {'row': 3, 'kind': 'last_name_missing', 'detail': null},
          ],
        }),
        200,
      );
    }));

    final check = await api.checkImport(7, _request);

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://api.test/companies/7/employees/import/check');
    expect(EmployeeImportRequest.fromJson(jsonDecode(sent.body) as Map<String, Object?>).rows.first.groups, ['Blue collar']);
    expect([for (final p in check.problems) (p.row, p.kind)], [(3, EmployeeImportProblemKind.lastNameMissing)]);
  });

  test('importEmployees POSTs the rows and decodes the result', () async {
    late http.Request sent;
    final api = EmployeesApi(_transport((request) async {
      sent = request;
      return http.Response(
        jsonEncode({
          'added': 1,
          'skipped': [
            {'row': 3, 'kind': 'code_used', 'detail': 'DRI'},
          ],
        }),
        200,
      );
    }));

    final result = await api.importEmployees(7, _request);

    expect(sent.url.toString(), 'http://api.test/companies/7/employees/import');
    expect(result.added, 1);
    expect(result.skipped.single.detail, 'DRI');
  });

  test('an unknown problem kind is an invalid response', () async {
    final api = EmployeesApi(_transport((_) async => http.Response(
          jsonEncode({
            'problems': [
              {'row': 3, 'kind': 'something_new'},
            ],
          }),
          200,
        )));

    expect(api.checkImport(7, _request), throwsA(isA<ApiClientException>()));
  });
}

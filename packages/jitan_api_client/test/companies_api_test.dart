import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:test/test.dart';

CompaniesApi _api(MockClientHandler handler) => CompaniesApi(
      ApiTransport(baseUri: Uri.parse('http://api.test/'), httpClient: MockClient(handler)),
    );

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  test('decodes the company list', () async {
    late Uri requested;
    final api = _api((request) async {
      requested = request.url;
      return _json({
        'companies': [
          {'id': 1, 'name': 'Almeco', 'isActive': true, 'employeeCount': 48, 'lastUpdatedAt': '2026-10-07T09:30:00.000'},
        ],
      }, 200);
    });

    final companies = await api.listCompanies();

    expect(requested.toString(), 'http://api.test/companies');
    expect(companies.single.name, 'Almeco');
    expect(companies.single.lastUpdatedAt, DateTime(2026, 10, 7, 9, 30));
  });

  test('sends a trimmed search and omits a blank one', () async {
    final urls = <Uri>[];
    final api = _api((request) async {
      urls.add(request.url);
      return _json({'companies': <Object?>[]}, 200);
    });

    await api.listCompanies(search: ' Alm ');
    await api.listCompanies(search: '   ');

    expect(urls.map((u) => u.toString()), [
      'http://api.test/companies?search=Alm',
      'http://api.test/companies',
    ]);
  });

  test('maps a structured error to a server failure with its code', () async {
    final api = _api((_) async => _json({
          'error': {'code': 'forbidden', 'message': 'No access.'},
        }, 403));

    expect(
      api.listCompanies(),
      throwsA(isA<ApiClientException>()
          .having((e) => e.kind, 'kind', ApiFailureKind.server)
          .having((e) => e.statusCode, 'statusCode', 403)
          .having((e) => e.error?.code, 'code', 'forbidden')),
    );
  });

  test('maps an unstructured error body to invalidResponse', () async {
    final api = _api((_) async => http.Response('<html>Bad gateway</html>', 502));

    expect(
      api.listCompanies(),
      throwsA(isA<ApiClientException>().having((e) => e.kind, 'kind', ApiFailureKind.invalidResponse)),
    );
  });

  test('maps a contract mismatch to invalidResponse', () async {
    final api = _api((_) async => _json({'companies': [{'id': 'x'}]}, 200));

    expect(
      api.listCompanies(),
      throwsA(isA<ApiClientException>().having((e) => e.kind, 'kind', ApiFailureKind.invalidResponse)),
    );
  });

  test('maps a connection failure to network', () async {
    final api = _api((_) async => throw http.ClientException('Connection refused'));

    expect(
      api.listCompanies(),
      throwsA(isA<ApiClientException>().having((e) => e.kind, 'kind', ApiFailureKind.network)),
    );
  });
}

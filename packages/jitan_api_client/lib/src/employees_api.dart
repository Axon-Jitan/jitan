import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `/companies/{companyId}/employees` endpoints. Always company-scoped.
class EmployeesApi {
  const EmployeesApi(this._transport);

  final ApiTransport _transport;

  /// Employees of [companyId]. A blank or null [search] lists all of them.
  Future<List<EmployeeSummary>> listForCompany(int companyId, {String? search}) async {
    final term = search?.trim() ?? '';
    final json = await _transport.getJson(
      'companies/$companyId/employees',
      query: term.isEmpty ? null : {'search': term},
    );
    try {
      return EmployeeListResponse.fromJson(json).employees;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Employee list: ${e.message}');
    }
  }

  /// Creates an employee in [companyId]; returns it as the server stored it.
  Future<EmployeeSummary> create(int companyId, CreateEmployeeRequest request) async {
    final json = await _transport.postJson('companies/$companyId/employees', request.toJson());
    try {
      return EmployeeSummary.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(201, 'Created employee: ${e.message}');
    }
  }
}

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
}

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

  /// Employees of every company the user may see, each once (no "Current
  /// company" chosen). A blank or null [search] lists all of them.
  Future<List<EmployeeSummary>> listAll({String? search}) async {
    final term = search?.trim() ?? '';
    final json = await _transport.getJson('employees', query: term.isEmpty ? null : {'search': term});
    try {
      return EmployeeListResponse.fromJson(json).employees;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Employee list: ${e.message}');
    }
  }

  /// One employee of [companyId].
  Future<EmployeeDetails> details(int companyId, int userId) async {
    final json = await _transport.getJson('companies/$companyId/employees/$userId');
    try {
      return EmployeeDetails.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Employee details: ${e.message}');
    }
  }

  /// A new temporary QR for [userId] (onboarding, or recovery after Reset
  /// account access): 10 minutes, single use; the previous one of the same
  /// purpose stops working. A credential: show it only as a QR, never log it.
  Future<TemporaryQrResponse> temporaryQr(int companyId, int userId, TemporaryQrPurpose purpose) async {
    final json = await _transport.postJson('companies/$companyId/employees/$userId/${purpose.wireName}-qr', const {});
    try {
      return TemporaryQrResponse.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Temporary QR: ${e.message}');
    }
  }

  /// Creates an employee in [companyId]; returns it as the server stored it.
  /// HR/Admin "Reset account access": clears the employee's password and
  /// ends every session of theirs; a temporary recovery QR ([temporaryQr])
  /// then lets them set a new one. Fails with `account_not_activated` when
  /// there is nothing to reset.
  Future<void> resetAccess(int companyId, int userId) =>
      _transport.postNoContent('companies/$companyId/employees/$userId/reset-access');

  /// "Remove employee": hides the employee everywhere; they stay in the
  /// database (marked for deletion) with all their history.
  Future<void> remove(int companyId, int userId) =>
      _transport.postNoContent('companies/$companyId/employees/$userId/remove');

  Future<EmployeeSummary> create(int companyId, CreateEmployeeRequest request) async {
    final json = await _transport.postJson('companies/$companyId/employees', request.toJson());
    try {
      return EmployeeSummary.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(201, 'Created employee: ${e.message}');
    }
  }

  /// Import employees, preview: the rows of a file that can't be added to
  /// [companyId], and why. Every other row is ready.
  Future<EmployeeImportCheck> checkImport(int companyId, EmployeeImportRequest request) async {
    final json = await _transport.postJson('companies/$companyId/employees/import/check', request.toJson());
    try {
      return EmployeeImportCheck.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Import check: ${e.message}');
    }
  }

  /// Adds the ready rows of a file to [companyId] (all of them or none) and
  /// reports the rows skipped because of a problem.
  Future<EmployeeImportResult> importEmployees(int companyId, EmployeeImportRequest request) async {
    final json = await _transport.postJson('companies/$companyId/employees/import', request.toJson());
    try {
      return EmployeeImportResult.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Import: ${e.message}');
    }
  }
}

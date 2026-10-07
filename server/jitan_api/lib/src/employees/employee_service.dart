import 'package:jitan_models/jitan_models.dart';

import '../companies/company_repository.dart';
import '../http/api_exception.dart';
import 'employee_repository.dart';

/// Employee use cases. Everything is scoped to one company.
class EmployeeService {
  const EmployeeService(this._employees, this._companies);

  final EmployeeRepository _employees;
  final CompanyRepository _companies;

  /// Longest accepted search text. Longer input is rejected, not truncated.
  static const maxSearchLength = 100;

  /// Employees of [companyId], optionally filtered by name or code.
  /// 404 when the company does not exist or is marked for deletion.
  Future<List<EmployeeSummary>> listForCompany(int companyId, {String? search}) async {
    final term = search?.trim() ?? '';
    if (term.length > maxSearchLength) {
      throw const ApiException.badRequest('Search text must be at most $maxSearchLength characters.');
    }
    if (!await _companies.exists(companyId)) {
      throw ApiException.notFound('Company $companyId does not exist.');
    }
    return _employees.listForCompany(companyId, nameOrCodeContains: term.isEmpty ? null : term);
  }
}

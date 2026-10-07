import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';
import 'company_repository.dart';

/// Company use cases.
class CompanyService {
  const CompanyService(this._companies);

  final CompanyRepository _companies;

  /// Longest accepted search text. Longer input is rejected, not truncated.
  static const maxSearchLength = 100;

  /// Lists non-deleted companies, optionally filtered by name.
  /// Blank [search] means no filter.
  Future<List<CompanySummary>> listCompanies({String? search}) {
    final term = search?.trim() ?? '';
    if (term.length > maxSearchLength) {
      throw const ApiException.badRequest(
        'Search text must be at most $maxSearchLength characters.',
      );
    }
    return _companies.listCompanies(nameContains: term.isEmpty ? null : term);
  }
}

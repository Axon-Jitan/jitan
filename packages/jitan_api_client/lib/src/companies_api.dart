import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `/companies` endpoints.
class CompaniesApi {
  const CompaniesApi(this._transport);

  final ApiTransport _transport;

  /// `GET /companies`. A blank or null [search] lists all companies.
  Future<List<CompanySummary>> listCompanies({String? search}) async {
    final term = search?.trim() ?? '';
    final json = await _transport.getJson(
      'companies',
      query: term.isEmpty ? null : {'search': term},
    );
    try {
      return CompanyListResponse.fromJson(json).companies;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Company list: ${e.message}');
    }
  }

  /// `POST /companies`: a new, active company.
  Future<CompanySummary> create(CompanyRequest request) async =>
      _company(await _transport.postJson('companies', request.toJson()));

  /// `PUT /companies/{id}`: a new name.
  Future<CompanySummary> rename(int companyId, CompanyRequest request) async =>
      _company(await _transport.putJson('companies/$companyId', request.toJson()));

  Future<CompanySummary> deactivate(int companyId) async =>
      _company(await _transport.postJson('companies/$companyId/deactivate', const {}));

  Future<CompanySummary> reactivate(int companyId) async =>
      _company(await _transport.postJson('companies/$companyId/reactivate', const {}));

  static CompanySummary _company(Map<String, Object?> json) {
    try {
      return CompanySummary.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Company: ${e.message}');
    }
  }
}

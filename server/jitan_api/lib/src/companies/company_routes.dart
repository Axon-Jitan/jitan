import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'company_service.dart';

/// HTTP endpoints for companies. Consumer: the HR/Admin Companies page
/// (`apps/admin_web`, Figma `1524:*`).
///
/// - `GET /companies?search=<text>`: every non-deleted company.
/// - `POST /companies`: Add company (only the name).
/// - `PUT /companies/{id}`: rename.
/// - `POST /companies/{id}/deactivate`, `/reactivate`.
///
/// Not company-scoped: a new company has none yet.
class CompanyRoutes {
  const CompanyRoutes(this._authorizer, this._companies);

  final Authorizer _authorizer;
  final CompanyService _companies;

  static const _company = '/companies/<companyId|[0-9]+>';

  Router get router => Router()
    ..get('/companies', _list)
    ..post('/companies', _create)
    ..put(_company, _rename)
    ..post('$_company/deactivate', (Request r, String id) => _setActive(r, id, active: false))
    ..post('$_company/reactivate', (Request r, String id) => _setActive(r, id, active: true));

  Future<Response> _create(Request request) async {
    final identity = await _authorizer.require(request, Permission.manageCompanies);
    final company = await _companies.create(identity.userId, await _read(request));
    return jsonResponse(company.toJson(), statusCode: 201);
  }

  Future<Response> _rename(Request request, String companyId) async {
    final identity = await _authorizer.require(request, Permission.manageCompanies);
    final id = pathId(companyId, 'No such company.');
    return jsonResponse((await _companies.rename(identity.userId, id, await _read(request))).toJson());
  }

  Future<Response> _setActive(Request request, String companyId, {required bool active}) async {
    final identity = await _authorizer.require(request, Permission.manageCompanies);
    final id = pathId(companyId, 'No such company.');
    return jsonResponse((await _companies.setActive(identity.userId, id, active: active)).toJson());
  }

  static Future<CompanyRequest> _read(Request request) async {
    try {
      return CompanyRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }

  Future<Response> _list(Request request) async {
    await _authorizer.require(request, Permission.viewCompanies);
    final companies = await _companies.listCompanies(
      search: request.url.queryParameters['search'],
    );
    return jsonResponse(CompanyListResponse(companies: companies).toJson());
  }
}

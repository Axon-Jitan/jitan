import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/json_response.dart';
import 'company_service.dart';

/// HTTP endpoints for companies.
///
/// `GET /companies?search=<text>`: consumer is the HR/Admin Companies screen
/// (`apps/admin_web`).
class CompanyRoutes {
  const CompanyRoutes(this._authorizer, this._companies);

  final Authorizer _authorizer;
  final CompanyService _companies;

  Router get router => Router()..get('/companies', _list);

  Future<Response> _list(Request request) async {
    await _authorizer.require(request, Permission.viewCompanies);
    final companies = await _companies.listCompanies(
      search: request.url.queryParameters['search'],
    );
    return jsonResponse(CompanyListResponse(companies: companies).toJson());
  }
}

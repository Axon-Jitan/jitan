import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'companies/company_routes.dart';
import 'employees/employee_routes.dart';
import 'health/health_routes.dart';
import 'http/api_exception.dart';
import 'http/cors_middleware.dart';
import 'http/error_middleware.dart';
import 'languages/language_routes.dart';

final _log = Logger('http.requests');

/// Assembles the request pipeline:
///
/// ```text
/// request log → CORS → error mapping → /health*, /languages, /translations (public)
///                                    → identity → API routes             (authenticated)
/// ```
///
/// [identity] is the authentication middleware. Today it is the development
/// identity (or `null`, leaving every API route unauthenticated → 401).
/// Real authentication replaces it here and nowhere else.
Handler buildApp({
  required Set<String> corsOrigins,
  required HealthRoutes health,
  required CompanyRoutes companies,
  required EmployeeRoutes employees,
  required LanguageRoutes languages,
  Middleware? identity,
}) {
  final apiRoutes = Router(notFoundHandler: _notFound)
    ..mount('/', companies.router.call)
    ..mount('/', employees.router.call)
    ..mount('/', languages.authenticatedRouter.call);

  var api = const Pipeline();
  if (identity != null) api = api.addMiddleware(identity);

  final routes = Cascade()
      .add(health.router.call)
      .add(languages.publicRouter.call)
      .add(api.addHandler(apiRoutes.call))
      .handler;

  return const Pipeline()
      .addMiddleware(logRequests(logger: _logRequest))
      .addMiddleware(corsMiddleware(corsOrigins))
      .addMiddleware(errorMiddleware())
      .addHandler(routes);
}

Response _notFound(Request request) =>
    throw const ApiException.notFound('No such endpoint.');

void _logRequest(String message, bool isError) =>
    isError ? _log.severe(message) : _log.info(message);

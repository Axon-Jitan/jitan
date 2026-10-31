import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'activities/activity_routes.dart';
import 'auth/sign_in_routes.dart';
import 'companies/company_routes.dart';
import 'employees/employee_assignment_routes.dart';
import 'employees/employee_routes.dart';
import 'groups/group_routes.dart';
import 'locations/location_routes.dart';
import 'projects/project_routes.dart';
import 'reports/report_routes.dart';
import 'health/health_routes.dart';
import 'http/api_exception.dart';
import 'http/cors_middleware.dart';
import 'http/error_middleware.dart';
import 'languages/language_routes.dart';
import 'onboarding/onboarding_routes.dart';
import 'recovery/recovery_routes.dart';
import 'schedules/schedule_routes.dart';
import 'time_records/time_record_routes.dart';
import 'time_registration/time_registration_routes.dart';
import 'users/me_routes.dart';

final _log = Logger('http.requests');

/// Assembles the request pipeline:
///
/// ```text
/// request log → CORS → error mapping → /health*, /languages, /translations, /onboarding/*, /recovery/*, /auth/sign-in (public)
///                                    → identity → API routes             (authenticated)
/// ```
///
/// [authentication] runs in order before the API routes: session tokens,
/// then (development only) the development identity for requests without a
/// token. With none attaching an identity, API routes answer 401.
Handler buildApp({
  required Set<String> corsOrigins,
  required HealthRoutes health,
  required CompanyRoutes companies,
  required EmployeeRoutes employees,
  required EmployeeAssignmentRoutes assignments,
  required GroupRoutes groups,
  required LanguageRoutes languages,
  required LocationRoutes locations,
  required ProjectRoutes projects,
  required ActivityRoutes activities,
  required ReportRoutes reports,
  required OnboardingRoutes onboarding,
  required RecoveryRoutes recovery,
  required SignInRoutes signIn,
  required MeRoutes me,
  required TimeRegistrationRoutes timeRegistrations,
  required ScheduleRoutes schedules,
  required TimeRecordRoutes timeRecords,
  List<Middleware> authentication = const [],
}) {
  final apiRoutes = Router(notFoundHandler: _notFound)
    ..mount('/', companies.router.call)
    ..mount('/', employees.router.call)
    ..mount('/', assignments.router.call)
    ..mount('/', groups.router.call)
    ..mount('/', locations.router.call)
    ..mount('/', projects.router.call)
    ..mount('/', activities.router.call)
    ..mount('/', reports.router.call)
    ..mount('/', languages.authenticatedRouter.call)
    ..mount('/', me.router.call)
    ..mount('/', timeRegistrations.router.call)
    ..mount('/', schedules.router.call)
    ..mount('/', timeRecords.router.call);

  var api = const Pipeline();
  for (final middleware in authentication) {
    api = api.addMiddleware(middleware);
  }

  final routes = Cascade()
      .add(health.router.call)
      .add(languages.publicRouter.call)
      .add(onboarding.router.call)
      .add(recovery.router.call)
      .add(signIn.router.call)
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

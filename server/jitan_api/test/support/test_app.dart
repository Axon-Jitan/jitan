import 'dart:convert';

import 'package:jitan_api/src/app.dart';
import 'package:jitan_api/src/auth/authorizer.dart';
import 'package:jitan_api/src/auth/development_identity_middleware.dart';
import 'package:jitan_api/src/companies/company_routes.dart';
import 'package:jitan_api/src/companies/company_service.dart';
import 'package:jitan_api/src/config/app_environment.dart';
import 'package:jitan_api/src/employees/employee_routes.dart';
import 'package:jitan_api/src/employees/employee_service.dart';
import 'package:jitan_api/src/groups/group_routes.dart';
import 'package:jitan_api/src/health/health_routes.dart';
import 'package:jitan_api/src/languages/language_routes.dart';
import 'package:jitan_api/src/languages/language_service.dart';
import 'package:shelf/shelf.dart';

import 'fakes.dart';

/// The full request pipeline wired to fakes.
class TestApp {
  TestApp({
    int? devUserId = 1,
    Set<int> activeUserIds = const {1},
    bool allowPermissions = true,
    Set<String> corsOrigins = const {},
  }) {
    permissions = FixedPermissionEvaluator(allow: allowPermissions);
    handler = buildApp(
      corsOrigins: corsOrigins,
      health: HealthRoutes(databaseHealth),
      companies: CompanyRoutes(Authorizer(permissions), CompanyService(companies)),
      employees: EmployeeRoutes(
        Authorizer(permissions),
        EmployeeService(
          employees: employees,
          companies: companies,
          groups: groups,
          audit: audit,
          transactions: transactions,
          personalQrCode: () => 'QR-${++_qrCounter}',
        ),
      ),
      groups: GroupRoutes(Authorizer(permissions), groups),
      languages: LanguageRoutes(LanguageService(languages, translations)),
      identity: devUserId == null
          ? null
          : DevelopmentIdentityMiddleware(
              environment: AppEnvironment.test,
              devUserId: devUserId,
              users: FakeUserRepository(activeUserIds),
            ).middleware,
    );
  }

  final companies = FakeCompanyRepository();
  final employees = FakeEmployeeRepository();
  final groups = FakeGroupRepository();
  final audit = FakeAuditLog();
  final transactions = FakeTransactions();
  var _qrCounter = 0;
  final databaseHealth = FakeDatabaseHealthRepository();
  final languages = FakeLanguageRepository();
  final translations = FakeTranslationRepository();
  late final FixedPermissionEvaluator permissions;
  late final Handler handler;

  Future<Response> get(String path, {Map<String, String> headers = const {}}) =>
      Future.sync(() => handler(Request('GET', Uri.parse('http://localhost$path'), headers: headers)));

  /// POST with a raw body (already JSON-encoded, or deliberately malformed).
  Future<Response> post(String path, String body) => Future.sync(
        () => handler(Request('POST', Uri.parse('http://localhost$path'), body: body,
            headers: {'content-type': 'application/json'})),
      );
}

Future<Map<String, Object?>> jsonBody(Response response) async =>
    jsonDecode(await response.readAsString()) as Map<String, Object?>;

import 'dart:convert';

import 'package:jitan_api/src/app.dart';
import 'package:jitan_api/src/auth/authorizer.dart';
import 'package:jitan_api/src/auth/development_identity_middleware.dart';
import 'package:jitan_api/src/auth/session_tokens.dart';
import 'package:jitan_api/src/auth/sign_in_routes.dart';
import 'package:jitan_api/src/auth/sign_in_service.dart';
import 'package:jitan_api/src/users/account_service.dart';
import 'package:jitan_api/src/auth/token_authentication_middleware.dart';
import 'package:jitan_api/src/users/me_routes.dart';
import 'package:jitan_api/src/companies/company_routes.dart';
import 'package:jitan_api/src/companies/company_service.dart';
import 'package:jitan_api/src/config/app_environment.dart';
import 'package:jitan_api/src/employees/employee_assignment_routes.dart';
import 'package:jitan_api/src/employees/employee_assignment_service.dart';
import 'package:jitan_api/src/employees/employee_routes.dart';
import 'package:jitan_api/src/employees/employee_service.dart';
import 'package:jitan_api/src/groups/group_routes.dart';
import 'package:jitan_api/src/health/health_routes.dart';
import 'package:jitan_api/src/languages/language_routes.dart';
import 'package:jitan_api/src/languages/language_service.dart';
import 'package:jitan_api/src/languages/user_language_service.dart';
import 'package:jitan_api/src/time_registration/time_registration_routes.dart';
import 'package:jitan_api/src/time_registration/time_registration_service.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/onboarding/onboarding_routes.dart';
import 'package:jitan_api/src/onboarding/onboarding_service.dart';
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
    users = FakeUserRepository(activeUserIds, passwordHashes: onboarding.passwordHashes, onboarding: onboarding);
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
          credentials: credentials,
          personalQrCode: () => 'QR-${++_qrCounter}',
        ),
      ),
      assignments: EmployeeAssignmentRoutes(
        Authorizer(permissions),
        EmployeeAssignmentService(
          assignments: assignments,
          employees: employees,
          companies: companies,
          audit: audit,
          transactions: transactions,
          executor: unusedExecutor,
          userLanguages: userLanguages,
          languageChanges: languageChanges,
        ),
      ),
      groups: GroupRoutes(Authorizer(permissions), groups),
      languages: LanguageRoutes(LanguageService(languages, translations, languageChanges)),
      onboarding: OnboardingRoutes(
        OnboardingService(
          onboarding: onboarding,
          languages: languages,
          audit: audit,
          transactions: transactions,
          executor: unusedExecutor,
          sessions: sessions,
          hasher: hasher,
        ),
      ),
      signIn: SignInRoutes(
        SignInService(
          credentials: credentials,
          users: users,
          executor: unusedExecutor,
          sessions: sessions,
          hasher: hasher,
        ),
      ),
      timeRegistrations: TimeRegistrationRoutes(
        Authorizer(permissions),
        TimeRegistrationService(
          registrations: timeRegistrations,
          employees: employees,
          companies: companies,
          executor: unusedExecutor,
        ),
      ),
      me: MeRoutes(
        users,
        AccountService(
          credentials: credentials,
          users: users,
          audit: audit,
          transactions: transactions,
          sessions: sessions,
          hasher: hasher,
        ),
      ),
      authentication: [
        TokenAuthenticationMiddleware(tokens: sessions, users: users).middleware,
        if (devUserId != null)
          DevelopmentIdentityMiddleware(
            environment: AppEnvironment.test,
            devUserId: devUserId,
            users: users,
          ).middleware,
      ],
    );
  }

  final companies = FakeCompanyRepository();
  final employees = FakeEmployeeRepository();
  final assignments = FakeEmployeeAssignmentRepository();
  final groups = FakeGroupRepository();
  final audit = FakeAuditLog();
  final transactions = FakeTransactions();
  final onboarding = FakeOnboardingRepository();
  late final credentials = FakeCredentialRepository(onboarding);
  final unusedExecutor = UnusedExecutor();
  late final FakeUserRepository users;

  /// Fixed secret and clock so tokens are reproducible.
  DateTime now = DateTime.utc(2026, 10, 7, 12);
  late final sessions = SessionTokens(
    secret: 'test-session-secret-at-least-32-characters',
    lifetime: const Duration(days: 30),
    clock: () => now,
  );

  /// Cheap Argon2id parameters keep tests fast; production uses
  /// [Argon2idParameters.recommended].
  final hasher = const PasswordHasher(parameters: Argon2idParameters(memoryKiB: 8192, iterations: 1));
  var _qrCounter = 0;
  final databaseHealth = FakeDatabaseHealthRepository();
  final languages = FakeLanguageRepository();
  final userLanguages = FakeUserLanguageRepository();
  final timeRegistrations = FakeTimeRegistrationRepository();
  late final languageChanges = UserLanguageService(
    userLanguages: userLanguages,
    employees: employees,
    audit: audit,
    transactions: transactions,
  );
  final translations = FakeTranslationRepository();
  late final FixedPermissionEvaluator permissions;
  late final Handler handler;

  /// POST with `Authorization: Bearer <token>`.
  Future<Response> postAuthorized(String path, String body, String token) => Future.sync(
    () => handler(
      Request(
        'POST',
        Uri.parse('http://localhost$path'),
        body: body,
        headers: {'content-type': 'application/json', 'authorization': 'Bearer $token'},
      ),
    ),
  );

  /// GET with `Authorization: Bearer <token>`.
  Future<Response> getAuthorized(String path, String token) => get(path, headers: {'authorization': 'Bearer $token'});

  Future<Response> get(String path, {Map<String, String> headers = const {}}) =>
      Future.sync(() => handler(Request('GET', Uri.parse('http://localhost$path'), headers: headers)));

  /// PUT with a raw body (already JSON-encoded, or deliberately malformed).
  Future<Response> put(String path, String body) => Future.sync(
    () => handler(
      Request('PUT', Uri.parse('http://localhost$path'), body: body, headers: {'content-type': 'application/json'}),
    ),
  );

  /// POST with a raw body (already JSON-encoded, or deliberately malformed).
  Future<Response> post(String path, String body) => Future.sync(
    () => handler(
      Request('POST', Uri.parse('http://localhost$path'), body: body, headers: {'content-type': 'application/json'}),
    ),
  );
}

Future<Map<String, Object?>> jsonBody(Response response) async =>
    jsonDecode(await response.readAsString()) as Map<String, Object?>;

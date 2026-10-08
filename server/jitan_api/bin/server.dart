import 'dart:async';
import 'dart:io';

import 'package:jitan_api/src/app.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/auth/authorizer.dart';
import 'package:jitan_api/src/auth/development_identity_middleware.dart';
import 'package:jitan_api/src/auth/development_permission_evaluator.dart';
import 'package:jitan_api/src/auth/credential_repository.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/auth/sign_in_routes.dart';
import 'package:jitan_api/src/auth/sign_in_service.dart';
import 'package:jitan_api/src/auth/permission_evaluator.dart';
import 'package:jitan_api/src/auth/session_tokens.dart';
import 'package:jitan_api/src/auth/token_authentication_middleware.dart';
import 'package:jitan_api/src/auth/unconfigured_permission_evaluator.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/companies/company_routes.dart';
import 'package:jitan_api/src/companies/company_service.dart';
import 'package:jitan_api/src/config/app_config.dart';
import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/env_file.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_assignment_repository.dart';
import 'package:jitan_api/src/employees/employee_assignment_routes.dart';
import 'package:jitan_api/src/employees/employee_assignment_service.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/employees/employee_routes.dart';
import 'package:jitan_api/src/employees/employee_service.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/groups/group_routes.dart';
import 'package:jitan_api/src/health/database_health_repository.dart';
import 'package:jitan_api/src/health/health_routes.dart';
import 'package:jitan_api/src/languages/language_repository.dart';
import 'package:jitan_api/src/languages/language_routes.dart';
import 'package:jitan_api/src/languages/language_service.dart';
import 'package:jitan_api/src/languages/translation_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_routes.dart';
import 'package:jitan_api/src/onboarding/onboarding_service.dart';
import 'package:jitan_api/src/users/account_service.dart';
import 'package:jitan_api/src/users/me_routes.dart';
import 'package:jitan_api/src/users/user_repository.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

final _log = Logger('server');

Future<void> main() async {
  _configureLogging();

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment(_readEnvironment());
  } on ConfigException catch (e) {
    _log.severe('Refusing to start: ${e.message}');
    exitCode = 78; // EX_CONFIG
    return;
  } on FormatException catch (e) {
    _log.severe('Refusing to start: ${e.message}');
    exitCode = 78;
    return;
  }

  _log.info('Environment: ${config.environment.name}');
  _log.info('Database: ${config.database}');

  final db = Database.connect(config.database);
  final users = UserRepository(db);
  final companyRepository = CompanyRepository(db);
  final groupRepository = GroupRepository(db);

  final PermissionEvaluator permissions = config.environment.allowsDevelopmentMechanisms
      ? DevelopmentPermissionEvaluator(config.environment)
      : const UnconfiguredPermissionEvaluator();
  final authorizer = Authorizer(permissions);

  final sessionSecret = config.sessionSecret;
  final sessions = sessionSecret == null
      ? SessionTokens.withRandomSecret(lifetime: config.sessionLifetime)
      : SessionTokens(secret: sessionSecret, lifetime: config.sessionLifetime);
  if (sessionSecret == null) {
    _log.warning('JITAN_SESSION_SECRET not set: using a random one (development only); sessions end on restart.');
  }
  _log.info('Password hashing: ${config.passwordHashing}');
  final hasher = PasswordHasher(parameters: config.passwordHashing);

  final devUserId = config.devUserId;
  final authentication = [
    TokenAuthenticationMiddleware(tokens: sessions, users: users).middleware,
    if (devUserId != null)
      DevelopmentIdentityMiddleware(
        environment: config.environment,
        devUserId: devUserId,
        users: users,
      ).middleware,
  ];

  final handler = buildApp(
    corsOrigins: config.corsOrigins,
    health: HealthRoutes(DatabaseHealthRepository(db)),
    companies: CompanyRoutes(authorizer, CompanyService(companyRepository)),
    employees: EmployeeRoutes(
      authorizer,
      EmployeeService(
        employees: EmployeeRepository(db),
        companies: companyRepository,
        groups: groupRepository,
        audit: const AuditLogRepository(),
        transactions: db,
      ),
    ),
    assignments: EmployeeAssignmentRoutes(
      authorizer,
      EmployeeAssignmentService(
        assignments: const EmployeeAssignmentRepository(),
        employees: EmployeeRepository(db),
        companies: companyRepository,
        audit: const AuditLogRepository(),
        transactions: db,
        executor: db,
      ),
    ),
    groups: GroupRoutes(authorizer, groupRepository),
    languages: LanguageRoutes(LanguageService(LanguageRepository(db), TranslationRepository(db))),
    onboarding: OnboardingRoutes(
      OnboardingService(
        onboarding: const OnboardingRepository(),
        languages: LanguageRepository(db),
        audit: const AuditLogRepository(),
        transactions: db,
        executor: db,
        sessions: sessions,
        hasher: hasher,
      ),
    ),
    signIn: SignInRoutes(
      SignInService(
        credentials: const CredentialRepository(),
        users: users,
        executor: db,
        sessions: sessions,
        hasher: hasher,
      ),
    ),
    me: MeRoutes(
      users,
      AccountService(
        credentials: const CredentialRepository(),
        users: users,
        audit: const AuditLogRepository(),
        transactions: db,
        sessions: sessions,
        hasher: hasher,
      ),
    ),
    authentication: authentication,
  );

  final server = await shelf_io.serve(handler, config.httpHost, config.httpPort);
  _log.info('Jitan API listening on http://${server.address.host}:${server.port}');

  late final StreamSubscription<ProcessSignal> sigint;
  sigint = ProcessSignal.sigint.watch().listen((_) async {
    _log.info('Shutting down.');
    await sigint.cancel();
    await server.close();
    await db.close();
  });
}

/// Platform environment, plus a git-ignored `.env` in the working directory
/// when present (development convenience). Platform values win.
/// Every key is passed through, so the production guard sees any `JITAN_DEV_*`.
Map<String, String> _readEnvironment() {
  final envFile = File('.env');
  return {
    if (envFile.existsSync()) ...parseEnvFile(envFile.readAsLinesSync()),
    ...Platform.environment,
  };
}

void _configureLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    final line = StringBuffer('${record.time.toIso8601String()} '
        '${record.level.name.padRight(7)} ${record.loggerName}: ${record.message}');
    if (record.error != null) line.write('\n  ${record.error}');
    if (record.stackTrace != null) line.write('\n${record.stackTrace}');
    (record.level >= Level.SEVERE ? stderr : stdout).writeln(line);
  });
}

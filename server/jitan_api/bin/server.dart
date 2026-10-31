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
import 'package:jitan_api/src/auth/credential_access_repository.dart';
import 'package:jitan_api/src/auth/credential_permission_evaluator.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/companies/company_routes.dart';
import 'package:jitan_api/src/companies/company_service.dart';
import 'package:jitan_api/src/config/app_config.dart';
import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/config_sources.dart';
import 'package:jitan_api/src/config/listener_config.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_assignment_repository.dart';
import 'package:jitan_api/src/employees/employee_assignment_routes.dart';
import 'package:jitan_api/src/employees/employee_assignment_service.dart';
import 'package:jitan_api/src/employees/employee_import_service.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/employees/employee_routes.dart';
import 'package:jitan_api/src/employees/employee_service.dart';
import 'package:jitan_api/src/groups/group_management_repository.dart';
import 'package:jitan_api/src/groups/group_management_service.dart';
import 'package:jitan_api/src/groups/group_member_repository.dart';
import 'package:jitan_api/src/groups/group_member_service.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/groups/group_routes.dart';
import 'package:jitan_api/src/groups/group_setup_service.dart';
import 'package:jitan_api/src/health/database_health_repository.dart';
import 'package:jitan_api/src/health/health_routes.dart';
import 'package:jitan_api/src/languages/language_repository.dart';
import 'package:jitan_api/src/languages/language_routes.dart';
import 'package:jitan_api/src/projects/project_repository.dart';
import 'package:jitan_api/src/projects/project_routes.dart';
import 'package:jitan_api/src/projects/project_service.dart';
import 'package:jitan_api/src/reports/dashboard_service.dart';
import 'package:jitan_api/src/reports/report_routes.dart';
import 'package:jitan_api/src/reports/report_service.dart';
import 'package:jitan_api/src/time_records/week_plans.dart';
import 'package:jitan_api/src/locations/location_repository.dart';
import 'package:jitan_api/src/locations/location_routes.dart';
import 'package:jitan_api/src/locations/location_service.dart';
import 'package:jitan_api/src/languages/language_service.dart';
import 'package:jitan_api/src/languages/user_language_repository.dart';
import 'package:jitan_api/src/languages/user_language_service.dart';
import 'package:jitan_api/src/languages/translation_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_routes.dart';
import 'package:jitan_api/src/recovery/recovery_routes.dart';
import 'package:jitan_api/src/recovery/recovery_service.dart';
import 'package:jitan_api/src/temporary_qr/in_memory_temporary_token_store.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_service.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_tokens.dart';
import 'package:jitan_api/src/time_registration/time_registration_repository.dart';
import 'package:jitan_api/src/time_registration/time_registration_routes.dart';
import 'package:jitan_api/src/time_registration/time_registration_service.dart';
import 'package:jitan_api/src/time_records/my_day_service.dart';
import 'package:jitan_api/src/time_records/time_correction_service.dart';
import 'package:jitan_api/src/time_records/time_record_repository.dart';
import 'package:jitan_api/src/time_records/time_record_routes.dart';
import 'package:jitan_api/src/time_records/time_record_service.dart';
import 'package:jitan_api/src/time_registration/registration_rounding.dart';
import 'package:jitan_api/src/time_registration/time_registration_write_service.dart';
import 'package:jitan_api/src/time_registration/workplace_clock.dart';
import 'package:jitan_api/src/onboarding/onboarding_service.dart';
import 'package:jitan_api/src/schedules/schedule_editing_service.dart';
import 'package:jitan_api/src/schedules/schedule_repository.dart';
import 'package:jitan_api/src/schedules/schedule_routes.dart';
import 'package:jitan_api/src/schedules/schedule_service.dart';
import 'package:jitan_api/src/schedules/schedule_write_repository.dart';
import 'package:jitan_api/src/users/account_service.dart';
import 'package:jitan_api/src/users/me_routes.dart';
import 'package:jitan_api/src/users/user_repository.dart';
import 'package:jitan_api/src/schedules/employee_schedule_sync.dart';
import 'package:jitan_api/src/schedules/group_schedule_link_repository.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

final _log = Logger('server');

Future<void> main() async {
  _configureLogging();

  final AppConfig config;
  final SecurityContext? httpsContext;
  final Database db;
  final WorkplaceClock workplaceClock;
  try {
    config = AppConfig.fromSources(ConfigSources.load(Platform.environment));
    httpsContext = config.listener.securityContext();
    workplaceClock = WorkplaceClock(config.timeZone);
    db = Database.connect(config.database);
  } on ConfigException catch (e) {
    _log.severe('Refusing to start: ${e.message}');
    exitCode = 78; // EX_CONFIG
    return;
  }

  _log.info('Environment: ${config.environment.name}');
  _log.info('Database: ${config.database}');
  _log.info('Workplace time zone: ${workplaceClock.name}');
  if (!config.database.secure) {
    _log.warning('The database connection is not encrypted (development only).');
  } else if (!config.database.verifiesCertificate) {
    _log.warning('The database certificate is not verified (development only). '
        'Set JITAN_DB_TLS_FINGERPRINTS or JITAN_DB_TLS_CA_FILE.');
  }
  if (!config.listener.https && !config.environment.allowsDevelopmentMechanisms) {
    _log.warning('Serving plain HTTP: only behind an IT-managed HTTPS proxy. Set TLS_CERT and TLS_KEY for direct HTTPS.');
  }

  final users = UserRepository(db);
  final companyRepository = CompanyRepository(db);
  final groupRepository = GroupRepository(db);
  // PROPOSAL (ERD_GAPS GAP-15): groups own their schedule in tblGroupSchedule,
  // a table only in the local development database.
  final groupLinks = config.devGroupSchedules ? const GroupScheduleLinkRepository() : null;
  if (groupLinks != null) {
    _log.warning('JITAN_DEV_GROUP_SCHEDULES: using the proposed tblGroupSchedule (GAP-15, local database only).');
  }
  final scheduleSync = EmployeeScheduleSync(groupLinks: groupLinks);
  final scheduleService = ScheduleService(
    schedules: ScheduleRepository(db),
    groups: groupRepository,
    groupLinks: groupLinks,
    db: groupLinks == null ? null : db,
  );
  final scheduleEditing = ScheduleEditingService(
    writes: const ScheduleWriteRepository(),
    schedules: scheduleService,
    audit: const AuditLogRepository(),
    transactions: db,
    groupLinks: groupLinks,
  );
  final groupManagement = GroupManagementService(
    groups: const GroupManagementRepository(),
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
  );
  final groupMembers = GroupMemberService(
    members: GroupMemberRepository(db),
    assignments: const EmployeeAssignmentRepository(),
    employees: EmployeeRepository(db),
    audit: const AuditLogRepository(),
    scheduleSync: scheduleSync,
    transactions: db,
  );

  final PermissionEvaluator permissions = config.environment.allowsDevelopmentMechanisms
      ? DevelopmentPermissionEvaluator(config.environment)
      : CredentialPermissionEvaluator(CredentialAccessRepository(db));
  final authorizer = Authorizer(permissions);

  final sessionSecret = config.sessionSecret;
  final sessions = sessionSecret == null
      ? SessionTokens.withRandomSecret(lifetime: config.sessionLifetime)
      : SessionTokens(secret: sessionSecret, lifetime: config.sessionLifetime);
  if (sessionSecret == null) {
    _log.warning('JITAN_SESSION_SECRET not set: using a random one (development only); sessions end on restart.');
  }
  // Temporary onboarding/recovery QRs (GAP-04): state in this process's
  // memory, never MySQL; a restart invalidates outstanding QRs.
  final temporaryQr = TemporaryQrService(
    tokens: TemporaryQrTokens.withRandomKey(),
    store: InMemoryTemporaryTokenStore(),
  );
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

  final languageChanges = UserLanguageService(
    userLanguages: const UserLanguageRepository(),
    employees: EmployeeRepository(db),
    audit: const AuditLogRepository(),
    transactions: db,
  );

  final locationService = LocationService(
    locations: const LocationRepository(),
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
  );

  final timeRecordService = TimeRecordService(
    records: TimeRecordRepository(db),
    employees: EmployeeRepository(db),
    companies: companyRepository,
    clock: workplaceClock,
    schedules: ScheduleRepository(db),
    rounding: RegistrationRounding(ScheduleRepository(db)),
  );
  final employeeService = EmployeeService(
    employees: EmployeeRepository(db),
    companies: companyRepository,
    groups: groupRepository,
    audit: const AuditLogRepository(),
    transactions: db,
    temporaryQr: temporaryQr,
    scheduleSync: scheduleSync,
    schedules: scheduleService,
  );

  final handler = buildApp(
    corsOrigins: config.corsOrigins,
    health: HealthRoutes(DatabaseHealthRepository(db)),
    companies: CompanyRoutes(authorizer, CompanyService(companyRepository)),
    employees: EmployeeRoutes(
      authorizer,
      employeeService,
      EmployeeImportService(
        employees: EmployeeRepository(db),
        creator: employeeService,
        companies: companyRepository,
        groups: groupRepository,
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
        userLanguages: const UserLanguageRepository(),
        languageChanges: languageChanges,
        scheduleSync: scheduleSync,
      ),
    ),
    groups: GroupRoutes(
      authorizer,
      groupRepository,
      groupManagement,
      groupMembers,
      GroupSetupService(
        management: groupManagement,
        members: groupMembers,
        schedules: scheduleEditing,
        transactions: db,
        groupsOwnSchedules: groupLinks != null,
      ),
    ),
    languages: LanguageRoutes(LanguageService(LanguageRepository(db), TranslationRepository(db), languageChanges)),
    locations: LocationRoutes(authorizer, locationService),
    projects: ProjectRoutes(
      authorizer,
      ProjectService(
        projects: const ProjectRepository(),
        companies: companyRepository,
        employees: EmployeeRepository(db),
        locations: const LocationRepository(),
        audit: const AuditLogRepository(),
        transactions: db,
        executor: db,
      ),
    ),
    onboarding: OnboardingRoutes(
      OnboardingService(
        onboarding: const OnboardingRepository(),
        languages: LanguageRepository(db),
        audit: const AuditLogRepository(),
        transactions: db,
        executor: db,
        sessions: sessions,
        temporaryQr: temporaryQr,
        hasher: hasher,
      ),
    ),
    recovery: RecoveryRoutes(
      RecoveryService(
        accounts: const OnboardingRepository(),
        credentials: const CredentialRepository(),
        audit: const AuditLogRepository(),
        transactions: db,
        executor: db,
        sessions: sessions,
        temporaryQr: temporaryQr,
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
    timeRegistrations: TimeRegistrationRoutes(
      authorizer,
      TimeRegistrationService(
        registrations: TimeRegistrationRepository(db),
        employees: EmployeeRepository(db),
        companies: companyRepository,
        executor: db,
      ),
      TimeRegistrationWriteService(
        transactions: db,
        rounding: RegistrationRounding(ScheduleRepository(db)),
        clock: workplaceClock,
      ),
    ),
    schedules: ScheduleRoutes(
      authorizer,
      scheduleService,
      scheduleEditing,
    ),
    timeRecords: TimeRecordRoutes(
      authorizer,
      timeRecordService,
      TimeCorrectionService(
        transactions: db,
        employees: EmployeeRepository(db),
        companies: companyRepository,
        records: TimeRecordRepository(db),
        days: timeRecordService,
        rounding: RegistrationRounding(ScheduleRepository(db)),
        clock: workplaceClock,
      ),
      MyDayService(
        days: timeRecordService,
        records: TimeRecordRepository(db),
        plans: WeekPlans(ScheduleRepository(db)),
        clock: workplaceClock,
      ),
    ),
    reports: ReportRoutes(
      authorizer,
      ReportService(
        days: timeRecordService,
        plans: WeekPlans(ScheduleRepository(db)),
        employees: EmployeeRepository(db),
        companies: companyRepository,
        clock: workplaceClock,
      ),
      DashboardService(
        days: timeRecordService,
        plans: WeekPlans(ScheduleRepository(db)),
        employees: EmployeeRepository(db),
        companies: companyRepository,
        locations: locationService,
        clock: workplaceClock,
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

  final List<HttpServer> servers;
  try {
    servers = await _listen(config.listener, httpsContext);
  } on SocketException catch (e) {
    _log.severe('Refusing to start: cannot listen ${config.listener} (${e.osError?.message ?? e.message}).');
    await db.close();
    exitCode = 78;
    return;
  }
  for (final server in servers) {
    shelf_io.serveRequests(server, handler);
  }
  _log.info('Jitan API listening: ${config.listener}');

  // systemd stops the service with SIGTERM; Ctrl+C sends SIGINT. Windows
  // can't watch SIGTERM.
  final signals = [ProcessSignal.sigint, if (!Platform.isWindows) ProcessSignal.sigterm];
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  var stopping = false;
  for (final signal in signals) {
    subscriptions.add(signal.watch().listen((_) async {
      if (stopping) return;
      stopping = true;
      _log.info('Shutting down ($signal).');
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await Future.wait([for (final server in servers) server.close()]);
      await db.close();
    }));
  }
}

/// One server per address, all on the same port; HTTPS when [https] is
/// given. If a later address fails, the ones already open are closed again.
Future<List<HttpServer>> _listen(ListenerConfig listener, SecurityContext? https) async {
  final servers = <HttpServer>[];
  try {
    for (final address in listener.addresses) {
      servers.add(https == null
          ? await HttpServer.bind(address, listener.port)
          : await HttpServer.bindSecure(address, listener.port, https));
    }
    return servers;
  } catch (_) {
    await Future.wait([for (final server in servers) server.close(force: true)]);
    rethrow;
  }
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

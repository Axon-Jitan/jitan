import 'dart:convert';

import 'package:jitan_models/jitan_models.dart';
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
import 'package:jitan_api/src/employees/employee_import_service.dart';
import 'package:jitan_api/src/employees/employee_routes.dart';
import 'package:jitan_api/src/employees/employee_service.dart';
import 'package:jitan_api/src/groups/group_management_service.dart';
import 'package:jitan_api/src/groups/group_member_repository.dart';
import 'package:jitan_api/src/groups/group_member_service.dart';
import 'package:jitan_api/src/groups/group_routes.dart';
import 'package:jitan_api/src/groups/group_setup_service.dart';
import 'package:jitan_api/src/health/health_routes.dart';
import 'package:jitan_api/src/languages/language_routes.dart';
import 'package:jitan_api/src/languages/language_service.dart';
import 'package:jitan_api/src/languages/user_language_service.dart';
import 'package:jitan_api/src/locations/location_routes.dart';
import 'package:jitan_api/src/locations/location_service.dart';
import 'package:jitan_api/src/reports/dashboard_service.dart';
import 'package:jitan_api/src/reports/report_routes.dart';
import 'package:jitan_api/src/reports/report_service.dart';
import 'package:jitan_api/src/time_records/week_plans.dart';
import 'package:jitan_api/src/recovery/recovery_routes.dart';
import 'package:jitan_api/src/recovery/recovery_service.dart';
import 'package:jitan_api/src/schedules/schedule_editing_service.dart';
import 'package:jitan_api/src/schedules/schedule_routes.dart';
import 'package:jitan_api/src/schedules/schedule_service.dart';
import 'package:jitan_api/src/temporary_qr/in_memory_temporary_token_store.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_service.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_tokens.dart';
import 'package:jitan_api/src/time_records/my_day_service.dart';
import 'package:jitan_api/src/time_records/time_correction_service.dart';
import 'package:jitan_api/src/time_records/time_record_routes.dart';
import 'package:jitan_api/src/time_records/time_record_service.dart';
import 'package:jitan_api/src/time_registration/registration_rounding.dart';
import 'package:jitan_api/src/time_registration/time_registration_write_service.dart';
import 'package:jitan_api/src/time_registration/workplace_clock.dart';
import 'package:jitan_api/src/time_registration/time_registration_routes.dart';
import 'package:jitan_api/src/time_registration/time_registration_service.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/onboarding/onboarding_routes.dart';
import 'package:jitan_api/src/onboarding/onboarding_service.dart';
import 'package:shelf/shelf.dart';

import 'fake_locations.dart';
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
    onboarding.audit = audit;
    employees.activatedLookup =
        (id) => onboarding.users.containsKey(id) ? onboarding.passwordHashes.containsKey(id) : null;
    final employeeService = EmployeeService(
      employees: employees,
      companies: companies,
      groups: groups,
      audit: audit,
      transactions: transactions,
      credentials: credentials,
      temporaryQr: temporaryQr,
      accounts: onboarding,
      personalQrCode: () => 'QR-${++_qrCounter}',
      scheduleSync: scheduleSync,
    );
    handler = buildApp(
      corsOrigins: corsOrigins,
      health: HealthRoutes(databaseHealth),
      companies: CompanyRoutes(Authorizer(permissions), CompanyService(companies)),
      employees: EmployeeRoutes(
        Authorizer(permissions),
        employeeService,
        EmployeeImportService(
          employees: employees,
          creator: employeeService,
          companies: companies,
          groups: groups,
          transactions: transactions,
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
          scheduleSync: scheduleSync,
        ),
      ),
      groups: GroupRoutes(
        Authorizer(permissions),
        groups,
        groupManagement,
        groupMemberService,
        GroupSetupService(
          management: groupManagement,
          members: groupMemberService,
          schedules: scheduleEditing,
          transactions: transactions,
        ),
      ),
      languages: LanguageRoutes(LanguageService(languages, translations, languageChanges)),
      locations: LocationRoutes(
        Authorizer(permissions),
        LocationService(locations: locations, audit: audit, transactions: transactions, executor: UnusedExecutor()),
      ),
      onboarding: OnboardingRoutes(
        OnboardingService(
          onboarding: onboarding,
          languages: languages,
          audit: audit,
          transactions: transactions,
          executor: unusedExecutor,
          sessions: sessions,
          temporaryQr: temporaryQr,
          hasher: hasher,
        ),
      ),
      recovery: RecoveryRoutes(
        RecoveryService(
          accounts: onboarding,
          credentials: credentials,
          audit: audit,
          transactions: transactions,
          executor: unusedExecutor,
          sessions: sessions,
          temporaryQr: temporaryQr,
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
        TimeRegistrationWriteService(
          transactions: transactions,
          rounding: RegistrationRounding(schedules),
          clock: WorkplaceClock('Europe/Brussels'),
          repository: timeRegistrationWrites,
          audit: audit,
          locations: locations,
          now: () => now,
        ),
      ),
      schedules: ScheduleRoutes(
        Authorizer(permissions),
        scheduleService,
        scheduleEditing,
      ),
      timeRecords: TimeRecordRoutes(Authorizer(permissions), timeRecordService, timeCorrections, myDays),
      reports: ReportRoutes(
        Authorizer(permissions),
        ReportService(
          days: timeRecordService,
          plans: WeekPlans(schedules),
          employees: employees,
          companies: companies,
          clock: WorkplaceClock('Europe/Brussels'),
          now: () => now,
        ),
        DashboardService(
          days: timeRecordService,
          plans: WeekPlans(schedules),
          employees: employees,
          companies: companies,
          locations: LocationService(locations: locations, audit: audit, transactions: transactions, executor: UnusedExecutor()),
          clock: WorkplaceClock('Europe/Brussels'),
          now: () => now,
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
  final schedules = FakeScheduleRepository();
  final timeRegistrationWrites = FakeTimeRegistrationWriteRepository();
  final timeRecords = FakeTimeRecordRepository();
  late final timeRecordService = TimeRecordService(
    records: timeRecords,
    employees: employees,
    companies: companies,
    clock: WorkplaceClock('Europe/Brussels'),
    schedules: schedules,
    rounding: RegistrationRounding(schedules),
    now: () => now,
  );
  late final myDays = MyDayService(
    days: timeRecordService,
    records: timeRecords,
    plans: WeekPlans(schedules),
    clock: WorkplaceClock('Europe/Brussels'),
    now: () => now,
  );
  late final timeCorrections = TimeCorrectionService(
    transactions: transactions,
    employees: employees,
    companies: companies,
    records: timeRecords,
    days: timeRecordService,
    rounding: RegistrationRounding(schedules),
    clock: WorkplaceClock('Europe/Brussels'),
    writes: timeRecords.writes,
    switches: timeRecords.switches,
    audit: audit,
    now: () => now,
  );
  final scheduleSync = FakeEmployeeScheduleSync();
  late final scheduleService = ScheduleService(schedules: schedules, groups: groups);
  final locations = FakeLocationRepository();
  final audit = FakeAuditLog();
  final transactions = FakeTransactions();
  final onboarding = FakeOnboardingRepository();
  late final credentials = FakeCredentialRepository(onboarding);
  final unusedExecutor = UnusedExecutor();

  /// Group-page reads; replace with a fake to test them.
  late GroupMemberRepository groupMembers = GroupMemberRepository(unusedExecutor);
  late final groupManagement = GroupManagementService(
    groups: const UnusedGroupManagementRepository(),
    audit: audit,
    transactions: transactions,
    executor: unusedExecutor,
  );
  late final groupMemberService = GroupMemberService(
    members: groupMembers,
    assignments: assignments,
    employees: employees,
    audit: audit,
    scheduleSync: scheduleSync,
    transactions: transactions,
  );
  late final scheduleEditing = ScheduleEditingService(
    writes: const UnusedScheduleWriteRepository(),
    schedules: scheduleService,
    audit: audit,
    transactions: transactions,
  );
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
  /// Temporary onboarding/recovery QRs on the same clock as sessions.
  late final temporaryQrStore = InMemoryTemporaryTokenStore(clock: () => now);
  late final temporaryQr = TemporaryQrService(
    tokens: TemporaryQrTokens(key: List.filled(32, 42), clock: () => now),
    store: temporaryQrStore,
  );

  /// A fresh temporary QR value for [userId].
  Future<String> issueQr(int userId, TemporaryQrPurpose purpose) async => (await temporaryQr.issue(userId, purpose)).token;

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

  Future<Response> delete(String path) =>
      Future.sync(() => handler(Request('DELETE', Uri.parse('http://localhost$path'))));

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

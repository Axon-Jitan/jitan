import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/auth/permission_evaluator.dart';
import 'package:jitan_api/src/auth/request_identity.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/db_row.dart';
import 'package:jitan_api/src/database/sql_executor.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/health/database_health_repository.dart';
import 'package:jitan_api/src/languages/language_repository.dart';
import 'package:jitan_api/src/languages/translation_repository.dart';
import 'package:jitan_api/src/users/user_repository.dart';
import 'package:jitan_models/jitan_models.dart';

/// In-memory stand-ins for unit tests. Integration tests use the real
/// repositories against a test database.

class FakeCompanyRepository implements CompanyRepository {
  FakeCompanyRepository([this.companies = const []]);

  List<CompanySummary> companies;
  Object? failWith;
  final searches = <String?>[];

  @override
  Future<List<CompanySummary>> listCompanies({String? nameContains}) async {
    searches.add(nameContains);
    if (failWith != null) throw failWith!;
    return companies;
  }

  /// IDs [exists] answers true for (non-MFD companies).
  Set<int> existingIds = {};

  @override
  Future<bool> exists(int companyId) async => existingIds.contains(companyId);
}

class FakeEmployeeRepository implements EmployeeRepository {
  /// companyId → employees.
  Map<int, List<EmployeeSummary>> byCompany = {};
  final calls = <(int, String?)>[];

  /// Codes [codeExists] reports as taken.
  Set<String> existingCodes = {};

  /// Thrown by [insertUser] when set (e.g. a duplicate-key race).
  Object? insertFailure;

  /// Every write, in order, e.g. `insertUser SBW`, `addToCompany 100→7`.
  final writes = <String>[];
  final insertedQrCodes = <String>[];
  String? lastPhone;
  var _nextId = 100;

  @override
  Future<List<EmployeeSummary>> listForCompany(int companyId, {String? nameOrCodeContains}) async {
    calls.add((companyId, nameOrCodeContains));
    return byCompany[companyId] ?? const [];
  }

  @override
  Future<bool> codeExists(SqlExecutor executor, String code) async => existingCodes.contains(code);

  @override
  Future<int> insertUser(
    SqlExecutor tx, {
    required String firstName,
    required String lastName,
    required String code,
    required String personalQrCode,
    required String? phone,
  }) async {
    if (insertFailure != null) throw insertFailure!;
    final id = _nextId++;
    writes.add('insertUser $code');
    insertedQrCodes.add(personalQrCode);
    lastPhone = phone;
    byCompany.putIfAbsent(-id, () => [
          EmployeeSummary(id: id, firstName: firstName, lastName: lastName, code: code, groups: const [], isActive: true),
        ]);
    return id;
  }

  @override
  Future<int> addToCompany(SqlExecutor tx, int userId, int companyId) async {
    writes.add('addToCompany $userId→$companyId');
    return 500 + userId;
  }

  @override
  Future<int> addToGroup(SqlExecutor tx, int userId, int groupId) async {
    writes.add('addToGroup $userId→$groupId');
    return 900 + userId;
  }

  @override
  Future<EmployeeSummary?> findInCompany(SqlExecutor executor, int companyId, int userId) async =>
      byCompany[-userId]?.single;

  /// (companyId, userId) → details.
  Map<(int, int), EmployeeDetails> details = {};

  @override
  Future<EmployeeDetails?> findDetails(int companyId, int userId) async => details[(companyId, userId)];
}

class FakeGroupRepository implements GroupRepository {
  List<GroupSummary> groups = const [];

  @override
  Future<List<GroupSummary>> listActive() async => groups;

  @override
  Future<bool> isAssignable(int groupId) async => groups.any((g) => g.id == groupId);
}

class FakeAuditLog implements AuditLogRepository {
  final events = <AuditEvent>[];

  /// Thrown by [record] when set, to prove the transaction rolls back.
  Object? failWith;

  @override
  Future<void> record(SqlExecutor tx, AuditEvent event) async {
    if (failWith != null) throw failWith!;
    events.add(event);
  }
}

/// Runs the action and records whether it committed or rolled back. Real
/// rollback behaviour is covered by the integration tests.
class FakeTransactions implements TransactionRunner {
  final outcomes = <String>[];

  @override
  Future<T> transaction<T>(Future<T> Function(SqlExecutor tx) action) async {
    try {
      final result = await action(_UnusedExecutor());
      outcomes.add('commit');
      return result;
    } catch (_) {
      outcomes.add('rollback');
      rethrow;
    }
  }
}

/// Fakes never run SQL; reaching this means a fake is missing.
class _UnusedExecutor implements SqlExecutor {
  @override
  Future<List<DbRow>> query(String sql, [Map<String, Object?> params = const {}]) =>
      throw UnimplementedError('Unit tests must not run SQL: $sql');

  @override
  Future<SqlWriteResult> execute(String sql, [Map<String, Object?> params = const {}]) =>
      throw UnimplementedError('Unit tests must not run SQL: $sql');
}

class FakeDatabaseHealthRepository implements DatabaseHealthRepository {
  Object? failWith;

  @override
  Future<void> ping() async {
    if (failWith != null) throw failWith!;
  }
}

class FakeUserRepository implements UserRepository {
  FakeUserRepository(this.activeUserIds);

  final Set<int> activeUserIds;

  @override
  Future<bool> isActiveUser(int userId) async => activeUserIds.contains(userId);
}

class FakeLanguageRepository implements LanguageRepository {
  /// Active languages only (the real query filters Active/MFD).
  List<Language> languages = const [];

  /// userID → codes of the user's active languages.
  Map<int, List<String>> userLanguages = const {};

  @override
  Future<List<Language>> listActiveLanguages() async => languages;

  @override
  Future<Language?> findActiveByCode(String code) async =>
      languages.where((l) => l.code == code).firstOrNull;

  @override
  Future<List<String>> activeLanguageCodesForUser(int userId) async => userLanguages[userId] ?? const [];
}

class FakeTranslationRepository implements TranslationRepository {
  /// languageID → texts.
  Map<int, Map<String, String>> texts = const {};

  @override
  Future<Map<String, String>> textsForLanguage(int languageId) async => texts[languageId] ?? const {};
}

class FixedPermissionEvaluator implements PermissionEvaluator {
  FixedPermissionEvaluator({required this.allow});

  final bool allow;

  /// (userId, permission, companyId) of every check.
  final checked = <(int, Permission, int?)>[];

  @override
  Future<bool> isAllowed(RequestIdentity identity, Permission permission, {int? companyId}) async {
    checked.add((identity.userId, permission, companyId));
    return allow;
  }
}

CompanySummary company(int id, String name, {bool active = true, int employees = 0}) =>
    CompanySummary(
      id: id,
      name: name,
      isActive: active,
      employeeCount: employees,
      lastUpdatedAt: null,
    );

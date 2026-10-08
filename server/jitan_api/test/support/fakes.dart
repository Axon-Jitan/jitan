import 'package:jitan_api/src/employees/employee_assignment_repository.dart';
import 'package:jitan_api/src/auth/credential_repository.dart';
import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/auth/permission_evaluator.dart';
import 'package:jitan_api/src/auth/request_identity.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database_exception.dart';
import 'package:jitan_api/src/database/db_row.dart';
import 'package:jitan_api/src/database/sql_executor.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/groups/group_repository.dart';
import 'package:jitan_api/src/health/database_health_repository.dart';
import 'package:jitan_api/src/languages/language_repository.dart';
import 'package:jitan_api/src/languages/translation_repository.dart';
import 'package:jitan_api/src/languages/user_language_repository.dart';
import 'package:jitan_api/src/onboarding/onboarding_repository.dart';
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
    byCompany.putIfAbsent(
      -id,
      () => [
        EmployeeSummary(
          id: id,
          firstName: firstName,
          lastName: lastName,
          code: code,
          groups: const [],
          isActive: true,
          isActivated: false,
        ),
      ],
    );
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
      byCompany[-userId]?.single ??
      (members.contains((companyId, userId))
          ? EmployeeSummary(
              id: userId,
              firstName: null,
              lastName: null,
              code: 'U$userId',
              groups: const [],
              isActive: true,
              isActivated: true,
            )
          : null);

  /// Users [lockUser] reports as existing; `null` = every user exists.
  Set<int>? existingUserIds;
  final lockedUsers = <int>[];

  @override
  Future<bool> lockUser(SqlExecutor tx, int userId) async {
    lockedUsers.add(userId);
    return existingUserIds?.contains(userId) ?? true;
  }

  /// (companyId, userId) pairs [findInCompany] finds.
  Set<(int, int)> members = {};

  /// (companyId, userId) → that member's current userQRcode (null = none).
  /// A pair missing from the map is not a member.
  Map<(int, int), String?> qrCodes = {};

  /// When true, [setPersonalQrCodeIfMissing] behaves as if another request
  /// stored [raceWinnerQr] first.
  bool loseQrRace = false;
  String raceWinnerQr = 'QR-OTHER';

  @override
  Future<({bool isMember, String? qrCode})> personalQrCode(SqlExecutor executor, int companyId, int userId) async =>
      qrCodes.containsKey((companyId, userId))
      ? (isMember: true, qrCode: qrCodes[(companyId, userId)])
      : (isMember: false, qrCode: null);

  @override
  Future<bool> setPersonalQrCodeIfMissing(SqlExecutor tx, int userId, String qrCode) async {
    final key = qrCodes.keys.firstWhere((k) => k.$2 == userId);
    if (loseQrRace) {
      qrCodes[key] = raceWinnerQr;
      return false;
    }
    if (qrCodes[key] != null) return false;
    writes.add('setQr $userId');
    qrCodes[key] = qrCode;
    return true;
  }

  /// (companyId, userId) → details.
  Map<(int, int), EmployeeDetails> details = {};

  @override
  Future<EmployeeDetails?> findDetails(int companyId, int userId) async => details[(companyId, userId)];
}

/// In-memory users by QR. [passwordHashes] stands in for `userPassword`.
class FakeOnboardingRepository implements OnboardingRepository {
  /// qrCode → user (without the password state).
  Map<String, ({int userId, String? firstName, String? lastName, String code, bool isActive})> users = {};

  /// Users marked for deletion (`userMFD = 1`).
  final markedForDeletion = <int>{};

  /// userId → stored hash (absent = NULL).
  final passwordHashes = <int, String>{};

  /// userId → company names.
  Map<int, List<String>> companies = {};

  /// When true, [setPasswordIfNotSet] acts as if another device won the race.
  bool loseRace = false;

  @override
  Future<OnboardingUser?> findByQrCode(SqlExecutor executor, String qrCode, {bool lockForUpdate = false}) async {
    final u = users[qrCode];
    if (u == null) return null;
    return (
      userId: u.userId,
      firstName: u.firstName,
      lastName: u.lastName,
      code: u.code,
      isActive: u.isActive,
      isMarkedForDeletion: markedForDeletion.contains(u.userId),
      passwordSet: passwordHashes.containsKey(u.userId),
    );
  }

  @override
  Future<List<String>> companyNames(SqlExecutor executor, int userId) async => companies[userId] ?? const [];

  @override
  Future<String?> passwordHash(SqlExecutor executor, int userId) async => passwordHashes[userId];

  @override
  Future<bool> setPasswordIfNotSet(SqlExecutor tx, int userId, String passwordHash) async {
    if (loseRace || passwordHashes.containsKey(userId)) return false;
    passwordHashes[userId] = passwordHash;
    return true;
  }

  /// userId → languageID stored during onboarding.
  final languages = <int, int>{};

  @override
  Future<void> setLanguage(SqlExecutor tx, int userId, int languageId) async => languages[userId] = languageId;
}

/// Credentials over the same users and hashes as [FakeOnboardingRepository].
class FakeCredentialRepository implements CredentialRepository {
  FakeCredentialRepository(this.onboarding);

  final FakeOnboardingRepository onboarding;

  @override
  Future<List<SignInCandidate>> candidatesByCode(SqlExecutor executor, String code) async => [
    for (final u in onboarding.users.values)
      if (u.code == code && onboarding.passwordHashes.containsKey(u.userId))
        (
          userId: u.userId,
          passwordHash: onboarding.passwordHashes[u.userId]!,
          isActive: u.isActive,
          isMarkedForDeletion: onboarding.markedForDeletion.contains(u.userId),
        ),
  ];

  @override
  Future<bool> replacePassword(SqlExecutor tx, int userId, {required String currentHash, required String newHash}) async {
    final user = onboarding.users.values.where((u) => u.userId == userId).firstOrNull;
    if (user == null || !user.isActive || onboarding.markedForDeletion.contains(userId)) return false;
    if (onboarding.passwordHashes[userId] != currentHash) return false;
    onboarding.passwordHashes[userId] = newHash;
    return true;
  }

  @override
  Future<bool> clearPassword(SqlExecutor tx, int userId) async => onboarding.passwordHashes.remove(userId) != null;
}

/// Junction tables in memory. [companies] are all companies (id → name,
/// active); MFD ones are simply absent.
class FakeEmployeeAssignmentRepository implements EmployeeAssignmentRepository {
  Map<int, ({String name, bool active})> companies = {};

  /// (userId, companyId) pairs, with their userCompanyID.
  final userCompanies = <(int, int), int>{};
  var _nextId = 100;

  Map<int, ({String name, bool active})> credentialGroups = {};

  /// (userId, credGroupId) pairs, with their userCredGroupID.
  final userCredentialGroups = <(int, int), int>{};

  @override
  Future<List<AssignmentOption>> credentialGroupOptions(SqlExecutor executor, int userId) async => [
    for (final MapEntry(key: id, value: g) in (credentialGroups.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
      if (g.active || userCredentialGroups.containsKey((userId, id)))
        AssignmentOption(id: id, name: g.name, isActive: g.active, isAssigned: userCredentialGroups.containsKey((userId, id))),
  ];

  @override
  Future<int?> addCredentialGroup(SqlExecutor tx, int userId, int credGroupId) async {
    if (userCredentialGroups.containsKey((userId, credGroupId))) return null;
    return userCredentialGroups[(userId, credGroupId)] = _nextId++;
  }

  /// Companies of a user: the [userCompanies] pairs.
  @override
  Future<List<int>> memberCompanyIds(SqlExecutor executor, int userId, {bool forUpdate = false}) async =>
      [for (final (u, c) in userCompanies.keys) if (u == userId) c]..sort();

  Map<int, ({String name, bool active})> groups = {};

  /// How many [addGroup] calls fail as MySQL deadlock victims first.
  var groupDeadlocks = 0;

  /// (userId, groupId) pairs, with their userGroupID.
  final userGroups = <(int, int), int>{};

  @override
  Future<List<AssignmentOption>> groupOptions(SqlExecutor executor, int userId) async => [
    for (final MapEntry(key: id, value: g) in (groups.entries.toList()..sort((a, b) => a.value.name.compareTo(b.value.name))))
      if (g.active || userGroups.containsKey((userId, id)))
        AssignmentOption(id: id, name: g.name, isActive: g.active, isAssigned: userGroups.containsKey((userId, id))),
  ];

  @override
  Future<int?> addGroup(SqlExecutor tx, int userId, int groupId) async {
    if (groupDeadlocks > 0) {
      groupDeadlocks--;
      throw const DatabaseQueryException('Deadlock found', errorCode: 1213);
    }
    if (userGroups.containsKey((userId, groupId))) return null;
    return userGroups[(userId, groupId)] = _nextId++;
  }

  @override
  Future<List<AssignmentOption>> companyOptions(SqlExecutor executor, int userId) async => [
    for (final MapEntry(key: id, value: c) in (companies.entries.toList()..sort((a, b) => a.value.name.compareTo(b.value.name))))
      if (c.active || userCompanies.containsKey((userId, id)))
        AssignmentOption(id: id, name: c.name, isActive: c.active, isAssigned: userCompanies.containsKey((userId, id))),
  ];

  @override
  Future<int?> addCompany(SqlExecutor tx, int userId, int companyId) async {
    if (userCompanies.containsKey((userId, companyId))) return null;
    return userCompanies[(userId, companyId)] = _nextId++;
  }
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
      final result = await action(UnusedExecutor());
      outcomes.add('commit');
      return result;
    } catch (_) {
      outcomes.add('rollback');
      rethrow;
    }
  }
}

/// Fakes never run SQL; reaching this means a fake is missing.
class UnusedExecutor implements SqlExecutor {
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
  FakeUserRepository(this.activeUserIds, {Map<int, String>? passwordHashes, this.onboarding})
    : passwordHashes = passwordHashes ?? {};

  final Set<int> activeUserIds;

  /// userId → stored hash (shared with [FakeOnboardingRepository] in TestApp).
  final Map<int, String> passwordHashes;

  /// Source of names/companies for [account].
  final FakeOnboardingRepository? onboarding;

  @override
  Future<bool> isActiveUser(int userId) async => activeUserIds.contains(userId);

  @override
  Future<String?> activePasswordHash(int userId) async =>
      activeUserIds.contains(userId) ? passwordHashes[userId] : null;

  @override
  Future<EmployeeAccount?> account(int userId) async {
    final user = onboarding?.users.values.where((u) => u.userId == userId).firstOrNull;
    if (user == null) return null;
    return EmployeeAccount(
      firstName: user.firstName,
      lastName: user.lastName,
      code: user.code,
      companies: onboarding!.companies[user.userId] ?? const [],
    );
  }
}

class FakeLanguageRepository implements LanguageRepository {
  /// Active languages only (the real query filters Active/MFD).
  List<Language> languages = const [];

  /// userID → codes of the user's active languages.
  Map<int, List<String>> userLanguages = const {};

  @override
  Future<List<Language>> listActiveLanguages() async => languages;

  @override
  Future<Language?> findActiveByCode(String code) async => languages.where((l) => l.code == code).firstOrNull;

  @override
  Future<List<String>> activeLanguageCodesForUser(int userId) async => userLanguages[userId] ?? const [];
}

class FakeUserLanguageRepository implements UserLanguageRepository {
  /// languageID → (name, code, active); MFD languages are simply absent.
  Map<int, ({String name, String code, bool active})> languages = {};

  /// userID → their tblUserLanguage rows.
  final rows = <int, List<UserLanguageRow>>{};
  var _nextId = 500;

  @override
  Future<List<UserLanguageRow>> assigned(SqlExecutor executor, int userId, {bool forUpdate = false}) async =>
      [...?rows[userId]];

  @override
  Future<void> save(SqlExecutor tx, int userId, int languageId, {UserLanguageRow? current}) async {
    final list = rows.putIfAbsent(userId, () => []);
    if (current == null) {
      list.add((userLanguageId: _nextId++, languageId: languageId));
    } else {
      list[list.indexOf(current)] = (userLanguageId: current.userLanguageId, languageId: languageId);
    }
  }

  @override
  Future<bool> isSelectable(SqlExecutor executor, int languageId) async => languages[languageId]?.active ?? false;

  @override
  Future<List<AssignmentOption>> options(SqlExecutor executor, int userId) async {
    final mine = {for (final r in rows[userId] ?? const <UserLanguageRow>[]) r.languageId};
    return [
      for (final MapEntry(key: id, value: l) in (languages.entries.toList()..sort((a, b) => a.value.name.compareTo(b.value.name))))
        if (l.active || mine.contains(id))
          AssignmentOption(id: id, name: l.name, code: l.code, isActive: l.active, isAssigned: mine.contains(id)),
    ];
  }
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

  /// Companies where every permission is refused even when [allow] is true.
  Set<int> deniedCompanies = {};

  /// (userId, permission, companyId) of every check.
  final checked = <(int, Permission, int?)>[];

  @override
  Future<bool> isAllowed(RequestIdentity identity, Permission permission, {int? companyId}) async {
    checked.add((identity.userId, permission, companyId));
    return allow && !deniedCompanies.contains(companyId);
  }
}

CompanySummary company(int id, String name, {bool active = true, int employees = 0}) =>
    CompanySummary(id: id, name: name, isActive: active, employeeCount: employees, lastUpdatedAt: null);

import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/auth/permission_evaluator.dart';
import 'package:jitan_api/src/auth/request_identity.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
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
  final checked = <(int, Permission)>[];

  @override
  Future<bool> isAllowed(RequestIdentity identity, Permission permission) async {
    checked.add((identity.userId, permission));
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

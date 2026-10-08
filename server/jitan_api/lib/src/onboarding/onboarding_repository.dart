import 'package:logging/logging.dart';

import '../database/sql_executor.dart';
import '../languages/user_language_repository.dart';
import '../employees/membership_filters.dart';

final _log = Logger('onboarding');

/// The `tblUser` row a temporary QR names, as onboarding and recovery need it.
/// Never carries the password hash itself, only whether one is set.
typedef OnboardingUser = ({
  int userId,
  String? firstName,
  String? lastName,
  String code,
  bool isActive,

  /// `userMFD`: marked for deletion. Refused like an inactive account.
  bool isMarkedForDeletion,

  /// `userPassword IS NOT NULL`: the onboarding-complete signal (decision
  /// 2026-10-07). Setting a password is the mandatory last onboarding step.
  bool passwordSet,
});

/// Data access for account setup (onboarding, and the account read by
/// recovery): `tblUser` by ID, and the user's language in `tblUserLanguage`.
class OnboardingRepository {
  const OnboardingRepository();

  /// The user [userId] (named by a verified temporary QR), or `null`. MFD
  /// users are returned too (flagged), so they can be refused explicitly.
  ///
  /// With [lockForUpdate] (inside a transaction) the row stays locked until
  /// commit, so two devices cannot both set the first password.
  Future<OnboardingUser?> findById(SqlExecutor executor, int userId, {bool lockForUpdate = false}) async {
    final rows = await executor.query(
      'SELECT userID, userName, userSurname, userCode, userActive, userMFD, '
      '(userPassword IS NOT NULL) AS passwordSet '
      'FROM tblUser WHERE userID = :userId'
      '${lockForUpdate ? ' FOR UPDATE' : ''}',
      {'userId': userId},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      userId: row.readInt('userID'),
      firstName: row.readOptionalString('userName'),
      lastName: row.readOptionalString('userSurname'),
      code: row.readString('userCode'),
      isActive: row.readBool('userActive'),
      isMarkedForDeletion: row.readBool('userMFD'),
      passwordSet: row.readBool('passwordSet'),
    );
  }

  /// Names of [userId]'s non-deleted companies.
  Future<List<String>> companyNames(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT c.companyName FROM tblUserCompany uc JOIN tblCompany c ON c.companyID = uc.companyID '
      'WHERE uc.userID = :userId AND ${MembershipFilters.activeCompany('uc')} AND c.companyMFD = 0 '
      'ORDER BY c.companyName',
      {'userId': userId},
    );
    return [for (final row in rows) row.readString('companyName')];
  }

  /// The stored `userPassword` hash, or `null` when none is set. Only for
  /// verifying a password server-side; never returned or logged.
  Future<String?> passwordHash(SqlExecutor executor, int userId) async {
    final rows = await executor.query('SELECT userPassword FROM tblUser WHERE userID = :userId', {'userId': userId});
    return rows.isEmpty ? null : rows.first.readOptionalString('userPassword');
  }

  /// Stores [passwordHash] only while no password is set; returns whether it
  /// did. The `IS NULL` condition is the database-level re-onboarding guard.
  Future<bool> setPasswordIfNotSet(SqlExecutor tx, int userId, String passwordHash) async =>
      (await tx.execute(
        'UPDATE tblUser SET userPassword = :hash WHERE userID = :userId AND userPassword IS NULL',
        {'hash': passwordHash, 'userId': userId},
      ))
          .affectedRows ==
      1;

  /// Makes [languageId] the user's language (one per user, CLARIFY-07): adds
  /// it when the user has none, changes it when the user has exactly one.
  /// With several assigned (inconsistent data), nothing is changed and the
  /// problem is logged rather than guessed at, so onboarding still finishes.
  Future<void> setLanguage(SqlExecutor tx, int userId, int languageId) async {
    const userLanguages = UserLanguageRepository();
    final current = await userLanguages.assigned(tx, userId, forUpdate: true);
    if (current.length > 1) {
      _log.warning('User $userId has ${current.length} languages (CLARIFY-07); onboarding choice not stored.');
      return;
    }
    await userLanguages.save(tx, userId, languageId, current: current.firstOrNull);
  }
}

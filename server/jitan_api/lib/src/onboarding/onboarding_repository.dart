import 'package:logging/logging.dart';

import '../database/sql_executor.dart';

final _log = Logger('onboarding');

/// The `tblUser` row a personal QR belongs to, as onboarding needs it.
/// Never carries the password hash itself, only whether one is set.
typedef OnboardingUser = ({
  int userId,
  String? firstName,
  String? lastName,
  String code,
  bool isActive,

  /// `userPassword IS NOT NULL`: the onboarding-complete signal (decision
  /// 2026-10-07). Setting a password is the mandatory last onboarding step.
  bool passwordSet,
});

/// Data access for onboarding: `tblUser` by `userQRcode`, and the user's
/// language in `tblUserLanguage`.
class OnboardingRepository {
  const OnboardingRepository();

  /// The non-MFD user whose `userQRcode` is exactly [qrCode], or `null`.
  ///
  /// With [lockForUpdate] (inside a transaction) the row stays locked until
  /// commit, so two devices cannot both complete onboarding.
  Future<OnboardingUser?> findByQrCode(SqlExecutor executor, String qrCode, {bool lockForUpdate = false}) async {
    final rows = await executor.query(
      'SELECT userID, userName, userSurname, userCode, userActive, '
      '(userPassword IS NOT NULL) AS passwordSet '
      'FROM tblUser WHERE userQRcode = :qrCode AND userMFD = 0'
      '${lockForUpdate ? ' FOR UPDATE' : ''}',
      {'qrCode': qrCode},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      userId: row.readInt('userID'),
      firstName: row.readOptionalString('userName'),
      lastName: row.readOptionalString('userSurname'),
      code: row.readString('userCode'),
      isActive: row.readBool('userActive'),
      passwordSet: row.readBool('passwordSet'),
    );
  }

  /// Names of [userId]'s non-deleted companies.
  Future<List<String>> companyNames(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT c.companyName FROM tblUserCompany uc JOIN tblCompany c ON c.companyID = uc.companyID '
      'WHERE uc.userID = :userId AND c.companyMFD = 0 ORDER BY c.companyName',
      {'userId': userId},
    );
    return [for (final row in rows) row.readString('companyName')];
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
  /// problem is logged rather than guessed at.
  Future<void> setLanguage(SqlExecutor tx, int userId, int languageId) async {
    final current = await tx.query('SELECT userLanguageID FROM tblUserLanguage WHERE userID = :userId', {
      'userId': userId,
    });
    if (current.isEmpty) {
      await tx.execute(
        'INSERT INTO tblUserLanguage (userID, languageID) VALUES (:userId, :languageId)',
        {'userId': userId, 'languageId': languageId},
      );
    } else if (current.length == 1) {
      await tx.execute(
        'UPDATE tblUserLanguage SET languageID = :languageId WHERE userLanguageID = :id',
        {'languageId': languageId, 'id': current.single.readInt('userLanguageID')},
      );
    } else {
      _log.warning('User $userId has ${current.length} languages (CLARIFY-07); onboarding choice not stored.');
    }
  }
}

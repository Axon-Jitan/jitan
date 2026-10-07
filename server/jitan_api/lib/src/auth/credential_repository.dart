import '../database/sql_executor.dart';

/// A `tblUser` row that could match a sign-in attempt. Carries the stored
/// hash for server-side verification only; never returned or logged.
typedef SignInCandidate = ({int userId, String passwordHash, bool isActive, bool isMarkedForDeletion});

/// Sign-in lookups and password writes on `tblUser.userPassword` after
/// onboarding (onboarding's first password is `OnboardingRepository`).
class CredentialRepository {
  const CredentialRepository();

  /// Users with employee code [code] that have a password. Normally one;
  /// several only if codes were reused (e.g. by a deleted user), so the
  /// caller checks each. Inactive and MFD users are included, flagged, so a
  /// correct password can be answered with "account unavailable".
  Future<List<SignInCandidate>> candidatesByCode(SqlExecutor executor, String code) async {
    final rows = await executor.query(
      'SELECT userID, userPassword, userActive, userMFD FROM tblUser '
      'WHERE userCode = :code AND userPassword IS NOT NULL ORDER BY userID LIMIT 5',
      {'code': code},
    );
    return [
      for (final row in rows)
        (
          userId: row.readInt('userID'),
          passwordHash: row.readString('userPassword'),
          isActive: row.readBool('userActive'),
          isMarkedForDeletion: row.readBool('userMFD'),
        ),
    ];
  }

  /// Replaces the password of an active, non-deleted, activated user;
  /// returns whether it did.
  Future<bool> replacePassword(SqlExecutor tx, int userId, String passwordHash) async =>
      (await tx.execute(
        'UPDATE tblUser SET userPassword = :hash '
        'WHERE userID = :userId AND userActive = 1 AND userMFD = 0 AND userPassword IS NOT NULL',
        {'hash': passwordHash, 'userId': userId},
      )).affectedRows ==
      1;

  /// Reset account access: clears the password, so the employee's existing
  /// QR starts account setup again and every session ends. Returns whether a
  /// password was set (an employee who never activated has nothing to reset).
  Future<bool> clearPassword(SqlExecutor tx, int userId) async =>
      (await tx.execute(
        'UPDATE tblUser SET userPassword = NULL WHERE userID = :userId AND userPassword IS NOT NULL',
        {'userId': userId},
      )).affectedRows ==
      1;
}

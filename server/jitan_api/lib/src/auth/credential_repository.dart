import '../database/sql_executor.dart';

/// A `tblUser` row that could match a sign-in attempt. Carries the stored
/// hash for server-side verification only; never returned or logged.
typedef SignInCandidate = ({int userId, String passwordHash, bool isActive, bool isMarkedForDeletion});

/// Sign-in lookups and password writes on `tblUser.userPassword` after
/// onboarding (onboarding's first password is `OnboardingRepository`):
/// change, reset, and the new password after a reset (recovery).
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

  /// The active, non-deleted users with employee code [code].
  Future<List<int>> activeByCode(SqlExecutor tx, String code) async => [
    for (final row in await tx.query(
      'SELECT userID FROM tblUser WHERE userCode = :code AND userActive = 1 AND userMFD = 0 LIMIT 5',
      {'code': code},
    ))
      row.readInt('userID'),
  ];

  /// Replaces the password of an active, non-deleted user, but only while
  /// the stored hash is still [currentHash] (the one the current password was
  /// verified against), so a concurrent change or reset is never overwritten.
  /// Returns whether it did.
  Future<bool> replacePassword(SqlExecutor tx, int userId, {required String currentHash, required String newHash}) async =>
      (await tx.execute(
        'UPDATE tblUser SET userPassword = :newHash '
        'WHERE userID = :userId AND userActive = 1 AND userMFD = 0 AND userPassword = :currentHash',
        {'newHash': newHash, 'currentHash': currentHash, 'userId': userId},
      )).affectedRows ==
      1;

  /// Recovery, and the very first password: stores the password of an active,
  /// non-deleted user, only while no password is set.
  /// Returns whether it did.
  Future<bool> setPasswordAfterReset(SqlExecutor tx, int userId, String passwordHash) async =>
      (await tx.execute(
        'UPDATE tblUser SET userPassword = :hash '
        'WHERE userID = :userId AND userActive = 1 AND userMFD = 0 AND userPassword IS NULL',
        {'hash': passwordHash, 'userId': userId},
      )).affectedRows ==
      1;

  /// Reset account access: clears the password, so every session ends and a
  /// temporary recovery QR can set a new one. Returns whether a password was
  /// set (an employee who never activated has nothing to reset).
  Future<bool> clearPassword(SqlExecutor tx, int userId) async =>
      (await tx.execute(
        'UPDATE tblUser SET userPassword = NULL WHERE userID = :userId AND userPassword IS NOT NULL',
        {'userId': userId},
      )).affectedRows ==
      1;
}

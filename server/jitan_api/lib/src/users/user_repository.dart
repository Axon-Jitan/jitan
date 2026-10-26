import 'package:jitan_models/jitan_models.dart';

import '../database/database.dart';
import '../employees/membership_filters.dart';

/// Data access for `tblUser`.
class UserRepository {
  const UserRepository(this._db);

  final Database _db;

  /// Whether [userId] exists with `userActive = 1` and `userMFD = 0`.
  Future<bool> isActiveUser(int userId) async {
    final rows = await _db.query(
      'SELECT 1 AS found FROM tblUser '
      'WHERE userID = :userId AND userActive = 1 AND userMFD = 0',
      {'userId': userId},
    );
    return rows.isNotEmpty;
  }

  /// The Terminal QR (`userQRcode`) of an active, non-deleted user; `null`
  /// when there is none. A credential: never logged.
  Future<String?> terminalQr(int userId) async {
    final rows = await _db.query(
      'SELECT userQRcode FROM tblUser WHERE userID = :userId AND userActive = 1 AND userMFD = 0',
      {'userId': userId},
    );
    final value = rows.isEmpty ? null : rows.first.readOptionalString('userQRcode');
    return value == null || value.isEmpty ? null : value;
  }

  /// The stored password hash of an active, non-deleted user; `null` when the
  /// user cannot sign in (unknown, inactive, deleted, or no password).
  /// Used only to check session tokens; never returned or logged.
  Future<String?> activePasswordHash(int userId) async {
    final rows = await _db.query(
      'SELECT userPassword FROM tblUser WHERE userID = :userId AND userActive = 1 AND userMFD = 0',
      {'userId': userId},
    );
    return rows.isEmpty ? null : rows.first.readOptionalString('userPassword');
  }

  /// [userId] as shown in the signed-in apps, or `null`.
  Future<EmployeeAccount?> account(int userId) async {
    final rows = await _db.query(
      'SELECT userName, userSurname, userCode FROM tblUser WHERE userID = :userId AND userMFD = 0',
      {'userId': userId},
    );
    if (rows.isEmpty) return null;
    final companies = await _db.query(
      'SELECT c.companyName FROM tblUserCompany uc JOIN tblCompany c ON c.companyID = uc.companyID '
      'WHERE uc.userID = :userId AND ${MembershipFilters.activeCompany('uc')} AND c.companyMFD = 0 '
      'ORDER BY c.companyName',
      {'userId': userId},
    );
    final row = rows.first;
    return EmployeeAccount(
      firstName: row.readOptionalString('userName'),
      lastName: row.readOptionalString('userSurname'),
      code: row.readString('userCode'),
      companies: [for (final c in companies) c.readString('companyName')],
    );
  }
}

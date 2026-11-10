import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';
import '../employees/membership_filters.dart';
import '../time_records/time_record_repository.dart';

/// One activity row of `tblTimeReg`. [addressId] is where it happened when
/// that is known, and its project when that address is a project's (D44).
typedef ActivityRow = ({int id, String typeName, DateTime at, int? addressId});

/// Data access for activities (D19, D22, D37, D44) on IT's tables: an
/// activity is a `tblTimeReg` row of an "Activity – …" type, and its
/// `addressID` says the project or the place. The Start and Finish rows are
/// not touched: an activity is a row of its own.
class ActivityRepository {
  const ActivityRepository();

  /// `tblTimeRegType` names of activities start with this.
  static const typePrefix = 'Activity – ';
  static const transportType = '${typePrefix}Transport';

  /// The active companies of [userId], by name.
  Future<List<MyCompany>> companies(SqlExecutor executor, int userId) async => [
    for (final row in await executor.query(
      'SELECT c.companyID, c.companyName, uc.userCompanyDefault FROM tblUserCompany uc '
      'JOIN tblCompany c ON c.companyID = uc.companyID AND c.companyActive = 1 AND c.companyMFD = 0 '
      'WHERE uc.userID = :user AND ${MembershipFilters.activeCompany('uc')} ORDER BY c.companyName, c.companyID',
      {'user': userId},
    ))
      MyCompany(
        id: row.readInt('companyID'),
        name: row.readString('companyName'),
        isDefault: row.readBool('userCompanyDefault'),
      ),
  ];

  /// [userId]'s activities from [from] up to [to], oldest first.
  Future<List<ActivityRow>> between(SqlExecutor executor, int userId, DateTime from, DateTime to) async =>
      (await ofUsers(executor, [userId], from, to))[userId] ?? const [];

  /// The activities of [userIds] from [from] up to [to], oldest first. The
  /// list holds only numbers from the server, each a bound placeholder.
  Future<Map<int, List<ActivityRow>>> ofUsers(
    SqlExecutor executor,
    List<int> userIds,
    DateTime from,
    DateTime to,
  ) async {
    if (userIds.isEmpty) return const {};
    final names = [for (var i = 0; i < userIds.length; i++) ':u$i'];
    final rows = await executor.query(
      'SELECT r.userID, r.timeRegID, t.timeRegTypeName, r.timeRegTimestamp, r.addressID FROM tblTimeReg r '
      'JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
      'WHERE r.userID IN (${names.join(', ')}) AND r.timeRegActive = 1 AND r.timeRegMFD = 0 '
      'AND t.timeRegTypeName LIKE :prefix AND r.timeRegTimestamp >= :from AND r.timeRegTimestamp < :to '
      'ORDER BY r.timeRegTimestamp, r.timeRegID',
      {
        for (var i = 0; i < userIds.length; i++) 'u$i': userIds[i],
        'prefix': '$typePrefix%',
        'from': TimeRecordRepository.sqlDateTime(from),
        'to': TimeRecordRepository.sqlDateTime(to),
      },
    );
    final byUser = <int, List<ActivityRow>>{};
    for (final row in rows) {
      byUser.putIfAbsent(row.readInt('userID'), () => []).add((
        id: row.readInt('timeRegID'),
        typeName: row.readString('timeRegTypeName'),
        at: row.readUtcDateTime('timeRegTimestamp'),
        addressId: row.readOptionalInt('addressID'),
      ));
    }
    return byUser;
  }

  /// Adds an activity row; `timeRegManualEntry = 0`, it is what happened.
  Future<int> insert(SqlExecutor tx, {required int userId, required int typeId, required DateTime at, int? addressId}) async =>
      (await tx.execute(
        'INSERT INTO tblTimeReg (userID, timeRegTypeID, timeRegTimestamp, timeRegManualEntry, addressID, '
        'timeRegActive, timeRegMFD) VALUES (:user, :type, :at, 0, :address, 1, 0)',
        {'user': userId, 'type': typeId, 'at': TimeRecordRepository.sqlDateTime(at), 'address': addressId},
      )).lastInsertId;
}

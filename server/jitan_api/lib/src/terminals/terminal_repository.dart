import 'package:jitan_models/jitan_models.dart';

import '../database/db_row.dart';
import '../database/loose_text.dart';
import '../database/sql_executor.dart';
import '../database/sql_in_list.dart';

/// A terminal as stored; [Terminal] adds what is calculated from it.
/// [kioskUserId] is the terminal's own `tblUser` (`userKioskMode = 1`), whose
/// `userPassword` holds the hash of the tablet's secret.
typedef TerminalRow = ({
  int id,
  String name,
  String serialNumber,
  TerminalTypeChoice type,
  bool isActive,
  int? kioskUserId,
  String? secretHash,
});

/// Who a Terminal QR belongs to.
typedef QrOwner = ({int id, String? firstName, bool isActive});

/// Data access for terminals on IT's tables (GAP-09, 2026-11-10): a terminal
/// is a `tblDevice` with `deviceMultiUser = 1`, its kind a `tblDeviceType`
/// row linked through `tblDeviceDeviceType`, and its secret the hashed
/// `userPassword` of a kiosk `tblUser` linked through `tblUserDevice`. Writes
/// run in the caller's transaction. Nothing is deleted: removing marks the
/// device, its links and the kiosk user `Active = 0, MFD = 1`.
class TerminalRepository {
  const TerminalRepository();

  /// `tblDeviceType` names Jitan reads as terminals; HR adds these rows.
  static const officeTypeName = 'Office terminal';
  static const vehicleTypeName = 'Vehicle terminal';

  /// Works like an office terminal (D18); its own kind so HR sees which is
  /// the workshop's (product owner, 2026-11-11).
  static const workshopTypeName = 'Workshop terminal';
  static const _typeNames = {'office': officeTypeName, 'vehicle': vehicleTypeName, 'workshop': workshopTypeName};

  static const _select =
      'SELECT d.deviceID, d.deviceName, d.deviceSN, d.deviceActive, y.deviceTypeID, y.deviceTypeName, '
      'k.userID AS kioskUserID, k.userPassword AS secretHash '
      'FROM tblDevice d '
      'JOIN tblDeviceDeviceType dt ON dt.deviceID = d.deviceID AND dt.deviceDeviceTypeActive = 1 AND dt.deviceDeviceTypeMFD = 0 '
      'JOIN tblDeviceType y ON y.deviceTypeID = dt.deviceTypeID AND y.deviceTypeName IN (:office, :vehicle, :workshop) '
      'LEFT JOIN (SELECT ud.deviceID, u.userID, u.userPassword FROM tblUserDevice ud '
      '  JOIN tblUser u ON u.userID = ud.userID AND u.userKioskMode = 1 AND u.userMFD = 0 '
      '  WHERE ud.userDeviceActive = 1 AND ud.userDeviceMFD = 0) k ON k.deviceID = d.deviceID '
      'WHERE d.deviceMFD = 0 AND d.deviceMultiUser = 1';

  /// The terminal kinds HR has added, oldest first.
  Future<List<TerminalTypeChoice>> types(SqlExecutor executor) async => [
    for (final row in await executor.query(
      'SELECT deviceTypeID, deviceTypeName FROM tblDeviceType '
      'WHERE deviceTypeName IN (:office, :vehicle, :workshop) AND deviceTypeActive = 1 AND deviceTypeMFD = 0 ORDER BY deviceTypeID',
      _typeNames,
    ))
      TerminalTypeChoice(id: row.readInt('deviceTypeID'), name: row.readString('deviceTypeName')),
  ];

  /// Every terminal, by name: they are shared by every company.
  Future<List<TerminalRow>> list(SqlExecutor executor) async =>
      (await executor.query('$_select ORDER BY d.deviceName, d.deviceID', _typeNames)).map(_toRow).toList();

  /// One terminal; `null` when it doesn't exist or was removed.
  Future<TerminalRow?> find(SqlExecutor executor, int deviceId) async {
    final rows = await executor.query('$_select AND d.deviceID = :id', {..._typeNames, 'id': deviceId});
    return rows.isEmpty ? null : _toRow(rows.first);
  }

  /// When each of [deviceIds] last registered a scan: the scan's audit row
  /// names the device (`tblEventLog.deviceID`), its registration the moment.
  /// The list holds only numbers from the server, each a bound placeholder.
  Future<Map<int, DateTime>> lastScans(SqlExecutor executor, List<int> deviceIds) async {
    if (deviceIds.isEmpty) return const {};
    final list = SqlInList('d', deviceIds);
    final rows = await executor.query(
      'SELECT e.deviceID, MAX(r.timeRegTimestamp) AS lastScan FROM tblEventLog e '
      'JOIN tblTimeReg r ON r.timeRegID = e.timeRegID '
      'WHERE e.deviceID IN (${list.placeholders}) GROUP BY e.deviceID',
      list.params,
    );
    return {for (final row in rows) row.readInt('deviceID'): row.readUtcDateTime('lastScan')};
  }

  /// Locks the terminal for the rest of the transaction; `false` when there
  /// is no such terminal.
  Future<bool> lock(SqlExecutor tx, int deviceId) async => (await tx.query(
    'SELECT deviceID FROM tblDevice WHERE deviceID = :id AND deviceMFD = 0 AND deviceMultiUser = 1 FOR UPDATE',
    {'id': deviceId},
  )).isNotEmpty;

  /// Whether another device, removed ones included (`deviceSN` is unique over
  /// them all), has [serialNumber] ignoring capitals and accents. A locking
  /// read, so two adds of the same number wait for each other.
  Future<bool> serialTaken(SqlExecutor tx, String serialNumber, {int? exceptDeviceId}) async => (await tx.query(
    'SELECT deviceID FROM tblDevice WHERE deviceSN $ignoringCaseAndAccents = :serial '
    '${exceptDeviceId == null ? '' : 'AND deviceID <> :except '}FOR UPDATE',
    {'serial': serialNumber, 'except': ?exceptDeviceId},
  )).isNotEmpty;

  /// Adds the device, its kind and its kiosk user (no password until a tablet
  /// connects). Returns the ids the audit row names.
  Future<({int deviceId, int kioskUserId, int userDeviceId, int deviceTypeLinkId})> insert(
    SqlExecutor tx,
    TerminalRequest terminal,
  ) async {
    final deviceId = (await tx.execute(
      'INSERT INTO tblDevice (deviceName, deviceSN, deviceMultiUser, deviceActive, deviceMFD) VALUES (:name, :serial, 1, 1, 0)',
      {'name': terminal.name, 'serial': terminal.serialNumber},
    )).lastInsertId;
    final typeLinkId = await _link(tx, deviceId, terminal.typeId);
    final kioskUserId = (await tx.execute(
      'INSERT INTO tblUser (userName, userSurname, userCode, userKioskMode, userActive, userMFD) '
      "VALUES (:name, '', :code, 1, 1, 0)",
      {'name': terminal.name, 'code': kioskCode(deviceId)},
    )).lastInsertId;
    final userDeviceId = (await tx.execute(
      'INSERT INTO tblUserDevice (deviceID, userID, userDeviceActive, userDeviceMFD) VALUES (:device, :user, 1, 0)',
      {'device': deviceId, 'user': kioskUserId},
    )).lastInsertId;
    return (deviceId: deviceId, kioskUserId: kioskUserId, userDeviceId: userDeviceId, deviceTypeLinkId: typeLinkId);
  }

  /// The kiosk user's `userCode`, unique like every code.
  static String kioskCode(int deviceId) => 'TERMINAL-$deviceId';

  Future<void> update(SqlExecutor tx, TerminalRow current, TerminalRequest terminal) async {
    await tx.execute(
      'UPDATE tblDevice SET deviceName = :name, deviceSN = :serial WHERE deviceID = :id',
      {'id': current.id, 'name': terminal.name, 'serial': terminal.serialNumber},
    );
    if (current.kioskUserId case final kiosk?) {
      await tx.execute('UPDATE tblUser SET userName = :name WHERE userID = :id', {'id': kiosk, 'name': terminal.name});
    }
    if (current.type.id != terminal.typeId) {
      await tx.execute(
        'UPDATE tblDeviceDeviceType SET deviceDeviceTypeActive = 0, deviceDeviceTypeMFD = 1 '
        'WHERE deviceID = :id AND deviceTypeID = :type',
        {'id': current.id, 'type': current.type.id},
      );
      await _link(tx, current.id, terminal.typeId);
    }
  }

  /// Links [deviceId] to [typeId], reactivating a link removed before.
  Future<int> _link(SqlExecutor tx, int deviceId, int typeId) async {
    final existing = await tx.query(
      'SELECT deviceDeviceTypeID FROM tblDeviceDeviceType WHERE deviceID = :device AND deviceTypeID = :type FOR UPDATE',
      {'device': deviceId, 'type': typeId},
    );
    if (existing.isNotEmpty) {
      final id = existing.first.readInt('deviceDeviceTypeID');
      await tx.execute(
        'UPDATE tblDeviceDeviceType SET deviceDeviceTypeActive = 1, deviceDeviceTypeMFD = 0 WHERE deviceDeviceTypeID = :id',
        {'id': id},
      );
      return id;
    }
    return (await tx.execute(
      'INSERT INTO tblDeviceDeviceType (deviceID, deviceTypeID, deviceDeviceTypeActive, deviceDeviceTypeMFD) '
      'VALUES (:device, :type, 1, 0)',
      {'device': deviceId, 'type': typeId},
    )).lastInsertId;
  }

  /// Turns the terminal and its kiosk user on or off together.
  Future<void> setActive(SqlExecutor tx, TerminalRow terminal, {required bool active}) async {
    await tx.execute('UPDATE tblDevice SET deviceActive = :active WHERE deviceID = :id', {'id': terminal.id, 'active': active ? 1 : 0});
    if (terminal.kioskUserId case final kiosk?) {
      await tx.execute('UPDATE tblUser SET userActive = :active WHERE userID = :id', {'id': kiosk, 'active': active ? 1 : 0});
    }
  }

  /// Connects a tablet; any tablet connected before is cut off.
  Future<void> setSecret(SqlExecutor tx, int kioskUserId, String secretHash) async => tx.execute(
    'UPDATE tblUser SET userPassword = :hash WHERE userID = :id AND userKioskMode = 1',
    {'id': kioskUserId, 'hash': secretHash},
  );

  /// The employee of a Terminal QR, active or not; `null` for no such QR.
  /// Kiosk users have none, and are never anyone's QR.
  Future<QrOwner?> ownerOfQr(SqlExecutor executor, String qrCode) async {
    final rows = await executor.query(
      'SELECT userID, userName, userActive FROM tblUser WHERE userQRcode = :qr AND userMFD = 0 AND userKioskMode = 0',
      {'qr': qrCode},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (id: row.readInt('userID'), firstName: row.readOptionalString('userName'), isActive: row.readBool('userActive'));
  }

  static TerminalRow _toRow(DbRow row) => (
    id: row.readInt('deviceID'),
    name: row.readString('deviceName'),
    serialNumber: row.readString('deviceSN'),
    type: TerminalTypeChoice(id: row.readInt('deviceTypeID'), name: row.readString('deviceTypeName')),
    isActive: row.readBool('deviceActive'),
    kioskUserId: row.readOptionalInt('kioskUserID'),
    secretHash: row.readOptionalString('secretHash'),
  );
}

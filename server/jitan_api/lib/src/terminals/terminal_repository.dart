import 'package:jitan_models/jitan_models.dart';

import '../database/db_row.dart';
import '../database/sql_executor.dart';
import '../employees/membership_filters.dart';
import '../time_records/time_record_repository.dart';

/// A terminal as stored; [Terminal] adds what is calculated from it.
typedef TerminalRow = ({
  int id,
  String name,
  TerminalTypeChoice type,
  int companyId,
  String companyName,
  int? addressId,
  String? addressName,
  String? plateNumber,
  bool scanningEnabled,
  String? deviceName,
  String? secretHash,
  DateTime? lastSeen,
  bool isActive,
});

/// Who a Terminal QR belongs to.
typedef QrOwner = ({int id, String? firstName, bool isActive});

/// Data access for terminals. PROPOSAL (docs/database/PROPOSED_TABLES.md):
/// these tables exist only in the local database until IT adds them. Writes
/// run in the caller's transaction. Nothing is deleted: removing sets
/// `terminalActive = 0, terminalMFD = 1` and forgets the tablet's secret.
class TerminalRepository {
  const TerminalRepository();

  static const _select =
      'SELECT t.terminalID, t.terminalName, t.terminalTypeID, y.terminalTypeName, t.companyID, c.companyName, '
      't.addressID, a.addressLogicalName, t.terminalPlateNumber, t.terminalQrEnabled, t.terminalDeviceName, '
      't.terminalSecretHash, t.terminalLastSeen, t.terminalActive '
      'FROM tblTerminal t '
      'JOIN tblTerminalType y ON y.terminalTypeID = t.terminalTypeID '
      'JOIN tblCompany c ON c.companyID = t.companyID '
      'LEFT JOIN tblAddress a ON a.addressID = t.addressID '
      'WHERE t.terminalMFD = 0';

  /// Whether this database has the proposed tables.
  Future<bool> available(SqlExecutor executor) async => (await executor.query(
    'SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :name',
    {'name': 'tblTerminal'},
  )).isNotEmpty;

  Future<List<TerminalTypeChoice>> types(SqlExecutor executor) async => [
    for (final row in await executor.query(
      'SELECT terminalTypeID, terminalTypeName FROM tblTerminalType '
      'WHERE terminalTypeActive = 1 AND terminalTypeMFD = 0 ORDER BY terminalTypeID',
    ))
      TerminalTypeChoice(id: row.readInt('terminalTypeID'), name: row.readString('terminalTypeName')),
  ];

  /// Every terminal of [companyIds], by name. The list holds only numbers from
  /// the server, and each goes in as a bound placeholder.
  Future<List<TerminalRow>> list(SqlExecutor executor, List<int> companyIds) async {
    if (companyIds.isEmpty) return const [];
    final names = [for (var i = 0; i < companyIds.length; i++) ':c$i'];
    final rows = await executor.query(
      '$_select AND t.companyID IN (${names.join(', ')}) ORDER BY t.terminalName, t.terminalID',
      {for (var i = 0; i < companyIds.length; i++) 'c$i': companyIds[i]},
    );
    return rows.map(_toRow).toList();
  }

  /// One terminal; `null` when it doesn't exist or was removed.
  Future<TerminalRow?> find(SqlExecutor executor, int terminalId) async {
    final rows = await executor.query('$_select AND t.terminalID = :id', {'id': terminalId});
    return rows.isEmpty ? null : _toRow(rows.first);
  }

  /// Locks the terminal for the rest of the transaction; `false` when
  /// [companyId] has no such terminal.
  Future<bool> lock(SqlExecutor tx, int companyId, int terminalId) async => (await tx.query(
    'SELECT terminalID FROM tblTerminal WHERE terminalID = :id AND companyID = :company AND terminalMFD = 0 FOR UPDATE',
    {'id': terminalId, 'company': companyId},
  )).isNotEmpty;

  Future<int> insert(SqlExecutor tx, TerminalRequest terminal) async => (await tx.execute(
    'INSERT INTO tblTerminal (companyID, terminalTypeID, addressID, terminalName, terminalPlateNumber, '
    'terminalQrEnabled, terminalActive, terminalMFD) VALUES (:company, :type, :address, :name, :plate, 1, 1, 0)',
    _parameters(terminal),
  )).lastInsertId;

  Future<void> update(SqlExecutor tx, int terminalId, TerminalRequest terminal) async => tx.execute(
    'UPDATE tblTerminal SET companyID = :company, terminalTypeID = :type, addressID = :address, '
    'terminalName = :name, terminalPlateNumber = :plate WHERE terminalID = :id',
    {'id': terminalId, ..._parameters(terminal)},
  );

  Future<void> setScanning(SqlExecutor tx, int terminalId, {required bool enabled}) async => tx.execute(
    'UPDATE tblTerminal SET terminalQrEnabled = :enabled WHERE terminalID = :id',
    {'id': terminalId, 'enabled': enabled ? 1 : 0},
  );

  Future<void> setActive(SqlExecutor tx, int terminalId, {required bool active}) async => tx.execute(
    'UPDATE tblTerminal SET terminalActive = :active WHERE terminalID = :id',
    {'id': terminalId, 'active': active ? 1 : 0},
  );

  Future<void> remove(SqlExecutor tx, int terminalId) async => tx.execute(
    'UPDATE tblTerminal SET terminalActive = 0, terminalMFD = 1, terminalSecretHash = NULL WHERE terminalID = :id',
    {'id': terminalId},
  );

  /// Connects a tablet; any tablet connected before is cut off.
  Future<void> setDevice(SqlExecutor tx, int terminalId, {required String secretHash, String? deviceName, required DateTime at}) async =>
      tx.execute(
        'UPDATE tblTerminal SET terminalSecretHash = :hash, terminalDeviceName = :device, terminalLastSeen = :at '
        'WHERE terminalID = :id',
        {'id': terminalId, 'hash': secretHash, 'device': deviceName, 'at': TimeRecordRepository.sqlDateTime(at)},
      );

  Future<void> markSeen(SqlExecutor executor, int terminalId, DateTime at) async => executor.execute(
    'UPDATE tblTerminal SET terminalLastSeen = :at WHERE terminalID = :id',
    {'id': terminalId, 'at': TimeRecordRepository.sqlDateTime(at)},
  );

  /// The owner of a Terminal QR, active or not; `null` for no such QR.
  Future<QrOwner?> ownerOfQr(SqlExecutor executor, String qrCode) async {
    final rows = await executor.query(
      'SELECT userID, userName, userActive FROM tblUser WHERE userQRcode = :qr AND userMFD = 0',
      {'qr': qrCode},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (id: row.readInt('userID'), firstName: row.readOptionalString('userName'), isActive: row.readBool('userActive'));
  }

  Future<bool> isMember(SqlExecutor executor, int userId, int companyId) async => (await executor.query(
    'SELECT 1 FROM tblUserCompany uc WHERE uc.userID = :user AND uc.companyID = :company '
    'AND ${MembershipFilters.activeCompany('uc')}',
    {'user': userId, 'company': companyId},
  )).isNotEmpty;

  static Map<String, Object?> _parameters(TerminalRequest terminal) => {
    'company': terminal.companyId,
    'type': terminal.typeId,
    'address': terminal.addressId,
    'name': terminal.name,
    'plate': terminal.plateNumber,
  };

  static TerminalRow _toRow(DbRow row) => (
    id: row.readInt('terminalID'),
    name: row.readString('terminalName'),
    type: TerminalTypeChoice(id: row.readInt('terminalTypeID'), name: row.readString('terminalTypeName')),
    companyId: row.readInt('companyID'),
    companyName: row.readString('companyName'),
    addressId: row.readOptionalInt('addressID'),
    addressName: row.readOptionalString('addressLogicalName'),
    plateNumber: row.readOptionalString('terminalPlateNumber'),
    scanningEnabled: row.readBool('terminalQrEnabled'),
    deviceName: row.readOptionalString('terminalDeviceName'),
    secretHash: row.readOptionalString('terminalSecretHash'),
    lastSeen: row.readOptionalString('terminalLastSeen') == null ? null : row.readUtcDateTime('terminalLastSeen'),
    isActive: row.readBool('terminalActive'),
  );
}

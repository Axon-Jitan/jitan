import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../companies/company_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../locations/location_repository.dart';
import '../temporary_qr/temporary_qr_service.dart';
import 'terminal_repository.dart';

/// HR/Admin managing terminals (Figma `1488:2` …, D18, D20). Every change is
/// audited in the same transaction; an action that changes nothing is not.
class TerminalService {
  TerminalService({
    required this._terminals,
    required this._companies,
    required this._locations,
    required this._temporaryQr,
    required this._audit,
    required this._transactions,
    required this._executor,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// `tblTerminalType` row with a number plate instead of a location.
  static const vehicleTypeName = 'Vehicle';

  /// A tablet checks in every minute; this long without one is offline.
  static const onlineFor = Duration(minutes: 3);

  final TerminalRepository _terminals;
  final CompanyRepository _companies;
  final LocationRepository _locations;
  final TemporaryQrService _temporaryQr;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;
  final DateTime Function() _now;

  Future<TerminalOptions> options() async {
    final types = await _terminals.types(_executor);
    return TerminalOptions(
      types: types,
      vehicleTypeIds: [
        for (final type in types)
          if (type.name == vehicleTypeName) type.id,
      ],
    );
  }

  /// Every terminal of the companies where [mayView] agrees.
  Future<List<Terminal>> list(Future<bool> Function(int companyId) mayView) async {
    final companies = [
      for (final company in await _companies.listCompanies())
        if (await mayView(company.id)) company.id,
    ];
    return [for (final row in await _terminals.list(_executor, companies)) _toTerminal(row)];
  }

  Future<Terminal> find(int companyId, int terminalId) async => _toTerminal(await _of(companyId, terminalId));

  Future<Terminal> create(int actorUserId, TerminalRequest request) async {
    final terminal = await _validated(request);
    final id = await _transactions.transaction((tx) async {
      final id = await _terminals.insert(tx, terminal);
      await _record(tx, AuditEventType.terminalCreated, actorUserId, terminal.companyId, id);
      return id;
    });
    return find(terminal.companyId, id);
  }

  /// [request] may move it to another company; the routes check both.
  Future<Terminal> update(int actorUserId, int companyId, int terminalId, TerminalRequest request) async {
    final terminal = await _validated(request);
    await _transactions.transaction((tx) async {
      if (!await _terminals.lock(tx, companyId, terminalId)) throw _notFound();
      await _terminals.update(tx, terminalId, terminal);
      await _record(tx, AuditEventType.terminalChanged, actorUserId, terminal.companyId, terminalId);
    });
    return find(terminal.companyId, terminalId);
  }

  Future<Terminal> setScanning(int actorUserId, int companyId, int terminalId, {required bool enabled}) async {
    await _transactions.transaction((tx) async {
      if (!await _terminals.lock(tx, companyId, terminalId)) throw _notFound();
      if ((await _of(companyId, terminalId, tx)).scanningEnabled == enabled) return;
      await _terminals.setScanning(tx, terminalId, enabled: enabled);
      await _record(tx, AuditEventType.terminalChanged, actorUserId, companyId, terminalId);
    });
    return find(companyId, terminalId);
  }

  Future<Terminal> setActive(int actorUserId, int companyId, int terminalId, {required bool active}) async {
    await _transactions.transaction((tx) async {
      if (!await _terminals.lock(tx, companyId, terminalId)) throw _notFound();
      if ((await _of(companyId, terminalId, tx)).isActive == active) return;
      await _terminals.setActive(tx, terminalId, active: active);
      await _record(
        tx,
        active ? AuditEventType.terminalReactivated : AuditEventType.terminalDeactivated,
        actorUserId,
        companyId,
        terminalId,
      );
    });
    return find(companyId, terminalId);
  }

  /// It leaves the list and its tablet is cut off; registrations stay.
  Future<void> remove(int actorUserId, int companyId, int terminalId) => _transactions.transaction((tx) async {
    if (!await _terminals.lock(tx, companyId, terminalId)) throw _notFound();
    await _terminals.remove(tx, terminalId);
    await _record(tx, AuditEventType.terminalRemoved, actorUserId, companyId, terminalId);
  });

  /// A temporary QR that connects a tablet to this terminal (GAP-04's rules);
  /// a new one invalidates the previous one. Temporary QRs carry one id: for
  /// this purpose it is the terminal's, not a user's.
  Future<TemporaryQrResponse> pairingQr(int actorUserId, int companyId, int terminalId) async {
    final terminal = await _of(companyId, terminalId);
    if (!terminal.isActive) {
      throw const ApiException.validation('terminal', 'Turn this terminal back on first.');
    }
    final issued = await _temporaryQr.issue(terminalId, TemporaryQrPurpose.terminalPairing);
    await _transactions.transaction(
      (tx) => _record(tx, AuditEventType.terminalPairingStarted, actorUserId, companyId, terminalId),
    );
    return TemporaryQrResponse(
      qrCode: issued.token,
      purpose: TemporaryQrPurpose.terminalPairing,
      expiresAt: issued.claims.expiresAt,
    );
  }

  Terminal _toTerminal(TerminalRow row) {
    final lastSeen = row.lastSeen;
    return Terminal(
      id: row.id,
      name: row.name,
      type: row.type,
      companyId: row.companyId,
      companyName: row.companyName,
      scanningEnabled: row.scanningEnabled,
      status: !row.isActive
          ? TerminalStatus.inactive
          : row.secretHash == null
          ? TerminalStatus.notConnected
          : lastSeen != null && _now().toUtc().difference(lastSeen) < onlineFor
          ? TerminalStatus.online
          : TerminalStatus.offline,
      addressId: row.addressId,
      addressName: row.addressName,
      plateNumber: row.plateNumber,
      deviceName: row.deviceName,
      lastSeen: lastSeen,
    );
  }

  Future<TerminalRow> _of(int companyId, int terminalId, [SqlExecutor? executor]) async {
    final row = await _terminals.find(executor ?? _executor, terminalId);
    if (row == null || row.companyId != companyId) throw _notFound();
    return row;
  }

  Future<TerminalRequest> _validated(TerminalRequest request) async {
    final terminal = request.trimmed();
    if (terminal.name.isEmpty) throw const ApiException.validation(TerminalRequest.fieldName, 'Give the terminal a name.');
    if (terminal.name.length > TerminalRequest.maxNameLength) {
      throw ApiException.validation(TerminalRequest.fieldName, 'At most ${TerminalRequest.maxNameLength} characters.');
    }
    if (!await _companies.exists(terminal.companyId)) {
      throw const ApiException.validation(TerminalRequest.fieldCompany, 'Choose a company.');
    }
    final options = await this.options();
    if (!options.types.any((t) => t.id == terminal.typeId)) {
      throw const ApiException.validation(TerminalRequest.fieldType, 'Choose a type.');
    }
    if (options.vehicleTypeIds.contains(terminal.typeId)) {
      final plate = terminal.plateNumber;
      if (plate == null) throw const ApiException.validation(TerminalRequest.fieldPlate, 'Give the number plate.');
      if (plate.length > TerminalRequest.maxPlateLength) {
        throw ApiException.validation(TerminalRequest.fieldPlate, 'At most ${TerminalRequest.maxPlateLength} characters.');
      }
      return TerminalRequest(name: terminal.name, typeId: terminal.typeId, companyId: terminal.companyId, plateNumber: plate);
    }
    final addressId = terminal.addressId;
    final location = addressId == null ? null : await _locations.find(_executor, addressId);
    if (location == null || !location.isActive) {
      throw const ApiException.validation(TerminalRequest.fieldAddress, 'Choose a location.');
    }
    return TerminalRequest(name: terminal.name, typeId: terminal.typeId, companyId: terminal.companyId, addressId: addressId);
  }

  Future<void> _record(SqlExecutor tx, AuditEventType type, int actorUserId, int companyId, int terminalId) => _audit.record(
    tx,
    AuditEvent(
      type: type,
      actorUserId: actorUserId,
      references: {EventLogReference.company: companyId, EventLogReference.terminal: terminalId},
    ),
  );

  static ApiException _notFound() => const ApiException.notFound('No such terminal.');
}

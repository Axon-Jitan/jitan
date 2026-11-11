import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../temporary_qr/temporary_qr_service.dart';
import 'terminal_presence.dart';
import 'terminal_repository.dart';

/// HR/Admin managing terminals (Figma `1507:2` …, D18, D20, GAP-09). A
/// terminal is shared by every company, so it has no company. Every change is
/// audited in the same transaction; an action that changes nothing is not.
class TerminalService {
  TerminalService({
    required this._terminals,
    required this._presence,
    required this._temporaryQr,
    required this._audit,
    required this._transactions,
    required this._executor,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// A tablet checks in every minute; this long without one is offline.
  static const onlineFor = Duration(minutes: 3);

  final TerminalRepository _terminals;
  final TerminalPresence _presence;
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
          if (type.name == TerminalRepository.vehicleTypeName) type.id,
      ],
    );
  }

  Future<List<Terminal>> list() async {
    final rows = await _terminals.list(_executor);
    final scans = await _terminals.lastScans(_executor, [for (final row in rows) row.id]);
    return [for (final row in rows) _toTerminal(row, scans[row.id])];
  }

  Future<Terminal> find(int terminalId) async {
    final row = await _of(terminalId);
    return _toTerminal(row, (await _terminals.lastScans(_executor, [row.id]))[row.id]);
  }

  Future<Terminal> create(int actorUserId, TerminalRequest request) async {
    final terminal = await _validated(request);
    final id = await _write(() => _transactions.transaction((tx) async {
      if (await _terminals.serialTaken(tx, terminal.serialNumber)) throw _serialTaken();
      final ids = await _terminals.insert(tx, terminal);
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.terminalCreated,
          actorUserId: actorUserId,
          references: {
            EventLogReference.device: ids.deviceId,
            EventLogReference.deviceDeviceType: ids.deviceTypeLinkId,
            EventLogReference.userDevice: ids.userDeviceId,
            EventLogReference.user: ids.kioskUserId,
          },
        ),
      );
      return ids.deviceId;
    }));
    return find(id);
  }

  Future<Terminal> update(int actorUserId, int terminalId, TerminalRequest request) async {
    final terminal = await _validated(request);
    await _write(() => _transactions.transaction((tx) async {
      if (!await _terminals.lock(tx, terminalId)) throw _notFound();
      final current = await _of(terminalId, tx);
      if (current.name == terminal.name && current.serialNumber == terminal.serialNumber && current.type.id == terminal.typeId) {
        return;
      }
      if (await _terminals.serialTaken(tx, terminal.serialNumber, exceptDeviceId: terminalId)) throw _serialTaken();
      await _terminals.update(tx, current, terminal);
      await _record(tx, AuditEventType.terminalChanged, actorUserId, terminalId);
    }));
    return find(terminalId);
  }

  Future<Terminal> setActive(int actorUserId, int terminalId, {required bool active}) async {
    await _transactions.transaction((tx) async {
      if (!await _terminals.lock(tx, terminalId)) throw _notFound();
      final current = await _of(terminalId, tx);
      if (current.isActive == active) return;
      await _terminals.setActive(tx, current, active: active);
      await _record(tx, active ? AuditEventType.terminalReactivated : AuditEventType.terminalDeactivated, actorUserId, terminalId);
    });
    return find(terminalId);
  }

  /// A temporary QR that connects a tablet to this terminal (GAP-04's rules);
  /// a new one invalidates the previous one. Temporary QRs carry one id: for
  /// this purpose it is the terminal's (`deviceID`), not a user's.
  Future<TemporaryQrResponse> pairingQr(int actorUserId, int terminalId) async {
    final terminal = await _of(terminalId);
    if (!terminal.isActive) {
      throw const ApiException.validation('terminal', 'Turn this terminal back on first.');
    }
    final issued = await _temporaryQr.issue(terminalId, TemporaryQrPurpose.terminalPairing);
    await _transactions.transaction((tx) => _record(tx, AuditEventType.terminalPairingStarted, actorUserId, terminalId));
    return TemporaryQrResponse(qrCode: issued.token, purpose: TemporaryQrPurpose.terminalPairing, expiresAt: issued.claims.expiresAt);
  }

  Terminal _toTerminal(TerminalRow row, DateTime? lastScan) {
    final lastSeen = _presence.lastSeen(row.id);
    final secret = row.secretHash;
    return Terminal(
      id: row.id,
      name: row.name,
      type: row.type,
      serialNumber: row.serialNumber,
      status: !row.isActive
          ? TerminalStatus.inactive
          : secret == null
          ? TerminalStatus.notConnected
          : lastSeen != null && _now().toUtc().difference(lastSeen) < onlineFor
          ? TerminalStatus.online
          : TerminalStatus.offline,
      lastSeen: lastSeen,
      lastScan: lastScan,
      connectionTag: secret == null ? null : sha256.convert(utf8.encode(secret)).toString().substring(0, 16),
    );
  }

  Future<TerminalRow> _of(int terminalId, [SqlExecutor? executor]) async =>
      await _terminals.find(executor ?? _executor, terminalId) ?? (throw _notFound());

  Future<TerminalRequest> _validated(TerminalRequest request) async {
    final terminal = request.trimmed();
    if (terminal.name.isEmpty) throw const ApiException.validation(TerminalRequest.fieldName, 'Give the terminal a name.');
    if (terminal.name.length > TerminalRequest.maxNameLength) {
      throw ApiException.validation(TerminalRequest.fieldName, 'At most ${TerminalRequest.maxNameLength} characters.');
    }
    if (terminal.serialNumber.isEmpty) {
      throw const ApiException.validation(TerminalRequest.fieldSerialNumber, 'Give the serial number on the tablet’s label.');
    }
    if (terminal.serialNumber.length > TerminalRequest.maxSerialNumberLength) {
      throw ApiException.validation(
        TerminalRequest.fieldSerialNumber,
        'At most ${TerminalRequest.maxSerialNumberLength} characters.',
      );
    }
    if (!(await _terminals.types(_executor)).any((t) => t.id == terminal.typeId)) {
      throw const ApiException.validation(TerminalRequest.fieldType, 'Choose a type.');
    }
    return terminal;
  }

  /// The unique key on `deviceSN` still catches an exact race.
  static Future<T> _write<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseQueryException catch (e) {
      if (e.isDuplicateKey) throw _serialTaken();
      if (e.isValueTooLong) throw const ApiException.badRequest('A value is longer than allowed.');
      rethrow;
    }
  }

  Future<void> _record(SqlExecutor tx, AuditEventType type, int actorUserId, int terminalId) => _audit.record(
    tx,
    AuditEvent(type: type, actorUserId: actorUserId, references: {EventLogReference.device: terminalId}),
  );

  static ApiException _serialTaken() => const ApiException(
    409,
    ApiErrorCode.duplicateSerialNumber,
    'Another terminal has this serial number.',
    field: TerminalRequest.fieldSerialNumber,
  );

  static ApiException _notFound() => const ApiException.notFound('No such terminal.');
}

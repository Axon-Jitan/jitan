import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:jitan_models/jitan_models.dart';

import '../activities/activity_service.dart';
import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../temporary_qr/temporary_qr_service.dart';
import '../time_records/my_day_service.dart';
import '../time_registration/time_registration_write_service.dart';
import '../time_registration/workplace_clock.dart';
import 'terminal_repository.dart';

/// What the tablet itself does (Figma `1489:2` …, D18, D41, D42): connect with
/// a temporary QR, then register whoever scans their Terminal QR. It holds a
/// secret of its own, stored hashed. An employee's first scan of the day
/// checks in and the next checks out; a repeat within [repeatWindow] changes
/// nothing, so a double scan can't end someone's day. Nothing works offline:
/// a scan the server didn't answer registered nothing.
class TerminalDeviceService {
  TerminalDeviceService({
    required this._terminals,
    required this._temporaryQr,
    required this._writes,
    required this._activities,
    required this._myDay,
    required this._audit,
    required this._transactions,
    required this._executor,
    required this._clock,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  static const repeatWindow = Duration(minutes: 1);

  /// How far ahead of the server's clock a scan may be.
  static const _allowedClockSkew = Duration(minutes: 2);
  static const _secretBytes = 32;

  final TerminalRepository _terminals;
  final TemporaryQrService _temporaryQr;
  final TimeRegistrationWriteService _writes;
  final ActivityService _activities;
  final MyDayService _myDay;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;
  final WorkplaceClock _clock;
  final DateTime Function() _now;
  final Random _random;

  /// Connects this tablet; a tablet connected before is cut off.
  Future<TerminalPairResponse> pair(TerminalPairRequest request) async => _temporaryQr.redeem(
    request.qrCode,
    TemporaryQrPurpose.terminalPairing,
    request.deviceId,
    (claims, {required isRetry}) async {
      final terminalId = claims.userId;
      final secret = base64Url.encode(List<int>.generate(_secretBytes, (_) => _random.nextInt(256))).replaceAll('=', '');
      final row = await _transactions.transaction((tx) async {
        final row = await _terminals.find(tx, terminalId);
        if (row == null || !row.isActive) {
          throw const ApiException(410, ApiErrorCode.qrExpired, 'This terminal is no longer available.');
        }
        await _terminals.setDevice(tx, terminalId, secretHash: _hash(secret), deviceName: _deviceName(request.deviceName), at: _now().toUtc());
        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.terminalPaired,
            actorUserId: null,
            references: {EventLogReference.company: row.companyId, EventLogReference.terminal: terminalId},
          ),
        );
        return row;
      });
      return TerminalPairResponse(token: '$terminalId.$secret', terminal: _info(row));
    },
  );

  /// The terminal behind an `Authorization: Bearer` [token]; 401 otherwise.
  Future<TerminalRow> authenticate(String? token) async {
    final dot = token?.indexOf('.') ?? -1;
    final id = dot <= 0 ? null : int.tryParse(token!.substring(0, dot));
    final row = id == null ? null : await _terminals.find(_executor, id);
    final stored = row?.secretHash;
    if (row == null || stored == null || !_sameHash(stored, _hash(token!.substring(dot + 1)))) {
      throw const ApiException.unauthenticated('This tablet is not connected.');
    }
    return row;
  }

  /// The tablet's regular check-in.
  Future<TerminalInfo> seen(TerminalRow terminal) async {
    await _terminals.markSeen(_executor, terminal.id, _now().toUtc());
    return _info(terminal);
  }

  Future<TerminalScanResult> scan(TerminalRow terminal, TerminalScanRequest request) async {
    final at = _toSecond(request.at);
    final owner = await _ownerAt(terminal, request.qrCode, at);
    await _terminals.markSeen(_executor, terminal.id, _now().toUtc());

    final day = (await _myDay.today(owner.id)).day;
    final start = day?.start?.actual, finish = day?.finish?.actual;
    final running = start != null && finish == null;
    final last = running ? start : finish;
    if (last != null && at.difference(last).abs() < repeatWindow) {
      return _result(owner, running ? TerminalScanOutcome.alreadyCheckedIn : TerminalScanOutcome.alreadyCheckedOut, last);
    }
    await _writes.register(
      owner.id,
      RegisterTimeRequest(
        boundary: running ? RegistrationBoundary.finish : RegistrationBoundary.start,
        method: TimeRegistrationMethod.qr,
        entry: RegistrationEntry.now,
        at: at,
        addressId: terminal.addressId,
      ),
      terminalId: terminal.id,
      companyId: terminal.companyId,
    );
    return _result(owner, running ? TerminalScanOutcome.checkedOut : TerminalScanOutcome.checkedIn, at);
  }

  /// "What are you working on?", right after checking in (D19).
  Future<TerminalScanResult> switchTo(TerminalRow terminal, TerminalSwitchRequest request) async {
    final at = _toSecond(request.at);
    final owner = await _ownerAt(terminal, request.qrCode, at);
    await _activities.switchTo(owner.id, SwitchActivityRequest(kind: request.kind, at: at, projectId: request.projectId));
    return _result(owner, TerminalScanOutcome.checkedIn, at);
  }

  Future<TerminalScanResult> _result(QrOwner owner, TerminalScanOutcome outcome, DateTime at) async {
    final mine = await _activities.mine(owner.id);
    final local = _clock.wallClockOf(at);
    return TerminalScanResult(
      outcome: outcome,
      timeLocal: '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
      firstName: owner.firstName,
      current: mine.current,
      projects: [
        for (final project in mine.projects)
          if (project.isCurrent) project,
      ],
    );
  }

  /// The employee of [qrCode], allowed to scan here at [at]. The refusals are
  /// the tablet's screens.
  Future<QrOwner> _ownerAt(TerminalRow terminal, String qrCode, DateTime at) async {
    if (!terminal.isActive || !terminal.scanningEnabled) {
      throw const ApiException(409, ApiErrorCode.terminalOff, 'Nobody can scan here right now.');
    }
    if (at.isAfter(_now().toUtc().add(_allowedClockSkew))) {
      throw const ApiException.validation(TerminalScanRequest.fieldAt, 'A scan can’t be in the future.');
    }
    final owner = await _terminals.ownerOfQr(_executor, qrCode.trim());
    if (owner == null) throw const ApiException(400, ApiErrorCode.qrNotRecognised, 'This QR code isn’t recognised.');
    if (!owner.isActive) throw const ApiException(403, ApiErrorCode.employeeUnavailable, 'This account can’t register.');
    if (!await _terminals.isMember(_executor, owner.id, terminal.companyId)) {
      throw const ApiException(403, ApiErrorCode.scanNotAllowed, 'This employee can’t register at this terminal.');
    }
    return owner;
  }

  static TerminalInfo _info(TerminalRow row) => TerminalInfo(
    id: row.id,
    name: row.name,
    companyName: row.companyName,
    canScan: row.isActive && row.scanningEnabled,
    placeName: row.addressName,
  );

  static String? _deviceName(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.length > _maxDeviceName ? trimmed.substring(0, _maxDeviceName) : trimmed;
  }

  static const _maxDeviceName = 100;

  static DateTime _toSecond(DateTime at) =>
      DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch ~/ 1000 * 1000, isUtc: true);

  /// The secret is long and random, so a plain hash is enough.
  static String _hash(String secret) => sha256.convert(utf8.encode(secret)).toString();

  static bool _sameHash(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }
}

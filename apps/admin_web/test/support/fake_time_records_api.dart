import 'dart:async';

import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Stand-in for [TimeRecordsApi]: each call waits on a [Completer] the test
/// controls.
class FakeTimeRecordsApi implements TimeRecordsApi {
  /// (from, to, companyId, search) of every call.
  final calls = <(DateTime, DateTime, int?, String?)>[];
  final _pending = <Completer<List<TimeRecordDay>>>[];

  @override
  Future<List<TimeRecordDay>> list({required DateTime from, required DateTime to, int? companyId, String? search}) {
    calls.add((from, to, companyId, search));
    final completer = Completer<List<TimeRecordDay>>();
    _pending.add(completer);
    return completer.future;
  }

  void succeed(List<TimeRecordDay> days) => _pending.last.complete(days);

  void fail(ApiClientException failure) => _pending.last.completeError(failure);

  /// Every write, e.g. `correct 7/1 2026-10-22 finish 16:22 Forgot`,
  /// `approve 7/1 55`, `nonWork 7/1 2026-10-22 Holiday`.
  final writes = <String>[];
  final _pendingWrites = <Completer<TimeRecordDay?>>[];

  Future<TimeRecordDay?> _write(String what) {
    writes.add(what);
    final completer = Completer<TimeRecordDay?>();
    _pendingWrites.add(completer);
    return completer.future;
  }

  void writeSucceeds([TimeRecordDay? day]) => _pendingWrites.last.complete(day);

  void writeFails(ApiClientException failure) => _pendingWrites.last.completeError(failure);

  @override
  Future<TimeRecordDay?> correct(int companyId, int userId, DateTime date, CorrectTimeRequest request) =>
      _write('correct $companyId/$userId ${TimeRecordDay.dateText(date)} ${request.boundary.wireName} ${request.time} ${request.reason}');

  @override
  Future<TimeRecordDay?> markNonWork(int companyId, int userId, DateTime date, String reason) =>
      _write('nonWork $companyId/$userId ${TimeRecordDay.dateText(date)} $reason');

  @override
  Future<TimeRecordDay?> approve(int companyId, int userId, int registrationId) =>
      _write('approve $companyId/$userId $registrationId');

  @override
  Future<TimeRecordDay?> reject(int companyId, int userId, int registrationId) =>
      _write('reject $companyId/$userId $registrationId');

  /// Answers every preview with [previewAnswer].
  String previewAnswer = '08:15';
  final previews = <String>[];

  @override
  Future<String> previewRounding(int companyId, int userId, DateTime date, RegistrationBoundary boundary, String time) async {
    previews.add('${boundary.wireName} $time');
    return previewAnswer;
  }
}

TimeRecordTime recordTime(String actual, {String? rounded, TimeRecordMethod method = TimeRecordMethod.qr, bool byHand = false, String? reason}) =>
    TimeRecordTime(
      actualId: 1,
      actual: DateTime.utc(2026, 10, 21),
      rounded: rounded == null ? null : DateTime.utc(2026, 10, 21),
      method: method,
      enteredByHand: byHand,
      actualLocal: actual,
      roundedLocal: rounded,
      reason: reason,
    );

TimeRecordDay recordDay(
  int employeeId,
  String first,
  String last,
  String code,
  DateTime date,
  TimeRecordStatus status, {
  TimeRecordTime? start,
  TimeRecordTime? finish,
  List<TimeRecordPending> pending = const [],
  List<TimeRecordEvent> events = const [],
  String? nonWorkReason,
  List<int> companyIds = const [7],
}) => TimeRecordDay(
  employeeId: employeeId,
  firstName: first,
  lastName: last,
  employeeCode: code,
  date: date,
  status: status,
  start: start,
  finish: finish,
  pending: pending,
  events: events,
  nonWorkReason: nonWorkReason,
  companyIds: companyIds,
);

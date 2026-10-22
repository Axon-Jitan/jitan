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
}) => TimeRecordDay(
  employeeId: employeeId,
  firstName: first,
  lastName: last,
  employeeCode: code,
  date: date,
  status: status,
  start: start,
  finish: finish,
);

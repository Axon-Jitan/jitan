import 'dart:async';

import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Stand-in for [SchedulesApi]. The list and options calls wait on
/// completers the test controls; writes are recorded and answered with
/// [writeResult] or fail with [writeFailure].
class FakeSchedulesApi implements SchedulesApi {
  final _lists = <Completer<List<GroupSchedule>>>[];
  final _options = <Completer<ScheduleOptions>>[];

  /// `(method, groupId, request)` of every write.
  final writes = <(String, int, Object?)>[];
  ApiClientException? writeFailure;
  GroupSchedule? writeResult;

  /// Completes writes only when the test calls [finishWrite] (saving state).
  bool holdWrites = false;
  Completer<void>? _heldWrite;

  int get listCalls => _lists.length;

  @override
  Future<List<GroupSchedule>> groupSchedules() {
    final completer = Completer<List<GroupSchedule>>();
    _lists.add(completer);
    return completer.future;
  }

  @override
  Future<ScheduleOptions> options() {
    final completer = Completer<ScheduleOptions>();
    _options.add(completer);
    return completer.future;
  }

  void succeedList(List<GroupSchedule> groups) => _lists.last.complete(groups);
  void failList(ApiClientException failure) => _lists.last.completeError(failure);
  void succeedOptions([ScheduleOptions options = testOptions]) => _options.last.complete(options);
  void failOptions(ApiClientException failure) => _options.last.completeError(failure);
  void finishWrite() => _heldWrite?.complete();

  Future<GroupSchedule> _write(String method, int groupId, Object? request) async {
    writes.add((method, groupId, request));
    if (holdWrites) {
      _heldWrite = Completer<void>();
      await _heldWrite!.future;
    }
    if (writeFailure case final failure?) throw failure;
    return writeResult ?? GroupSchedule(group: GroupSummary(id: groupId, name: 'Group $groupId'), status: GroupScheduleStatus.configured, singleGroupEmployeeCount: 1, variants: const []);
  }

  @override
  Future<GroupSchedule> setSchedule(int groupId, SetGroupScheduleRequest request) => _write('setSchedule', groupId, request);

  @override
  Future<GroupSchedule> setWorkHours(int groupId, SetWorkHoursRequest request) => _write('setWorkHours', groupId, request);

  @override
  Future<GroupSchedule> removeWorkHours(int groupId) => _write('removeWorkHours', groupId, null);

  @override
  Future<GroupSchedule> setBreaks(int groupId, SetBreaksRequest request) => _write('setBreaks', groupId, request);

  @override
  Future<GroupSchedule> removeBreaks(int groupId) => _write('removeBreaks', groupId, null);
}

const _days = [
  ScheduleDay(id: 11, name: 'Monday', weekday: 1),
  ScheduleDay(id: 12, name: 'Tuesday', weekday: 2),
  ScheduleDay(id: 13, name: 'Wednesday', weekday: 3),
  ScheduleDay(id: 14, name: 'Thursday', weekday: 4),
  ScheduleDay(id: 15, name: 'Friday', weekday: 5),
  ScheduleDay(id: 16, name: 'Saturday', weekday: 6),
  ScheduleDay(id: 17, name: 'Sunday', weekday: 7),
];

const testOptions = ScheduleOptions(
  days: _days,
  roundingIntervalMinutes: [5, 10, 15, 30, 60],
  maxToleranceMinutes: 60,
  breakLengthMinutes: [15, 30, 45, 60],
);

ScheduleDay testDay(int weekday) => _days[weekday - 1];

/// Work hours [start]–[finish] on [weekdays], up 15 at the start and down 15
/// at the finish, with [tolerance] minutes both ways.
List<WorkDaySchedule> workDays(List<int> weekdays, String start, String finish, {int tolerance = 5}) => [
  for (final weekday in weekdays)
    WorkDaySchedule(
      day: testDay(weekday),
      start: WorkBoundary(time: start, toleranceMinutes: tolerance, rounding: const ScheduleRounding(intervalMinutes: 15, roundUp: true)),
      finish: WorkBoundary(time: finish, toleranceMinutes: tolerance, rounding: const ScheduleRounding(intervalMinutes: 15, roundUp: false)),
    ),
];

List<BreakSchedule> breaks(List<int> weekdays, String start, int minutes) => [
  for (final weekday in weekdays) BreakSchedule(day: testDay(weekday), usualStart: start, lengthMinutes: minutes),
];

GroupSchedule groupSchedule(
  int id,
  String name, {
  GroupScheduleStatus status = GroupScheduleStatus.configured,
  List<WorkDaySchedule> work = const [],
  List<BreakSchedule> breakDays = const [],
  List<ScheduleVariant>? variants,
}) => GroupSchedule(
  group: GroupSummary(id: id, name: name),
  status: status,
  singleGroupEmployeeCount: status == GroupScheduleStatus.noSingleGroupEmployees ? 0 : 3,
  variants: variants ??
      (status == GroupScheduleStatus.configured
          ? [ScheduleVariant(employeeCount: 3, workDays: work, breaks: breakDays)]
          : const []),
);

/// A 400 validation_failed naming [field], as the server sends it.
abstract final class ApiClientExceptionFor {
  static ApiClientException validation(String field) =>
      ApiClientException.server(400, ApiError(code: ApiErrorCode.validationFailed, message: 'detail', field: field));
}

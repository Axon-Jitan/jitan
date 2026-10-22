import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';
import 'schedule_rows.dart';

/// The schedule form's choices from `GET /schedules/options`.
sealed class ScheduleOptionsState {
  const ScheduleOptionsState();
}

class ScheduleOptionsLoading extends ScheduleOptionsState {
  const ScheduleOptionsLoading();
}

class ScheduleOptionsLoaded extends ScheduleOptionsState {
  const ScheduleOptionsLoaded(this.options);

  final ScheduleOptions options;
}

class ScheduleOptionsFailed extends ScheduleOptionsState {
  const ScheduleOptionsFailed(this.failure);

  final ApiClientException failure;
}

/// A text key and its arguments, shown under the form.
typedef ScheduleFormMessage = ({String key, Map<String, Object> args});

/// The steps of the schedule wizard, in order.
enum ScheduleStep { group, hours, attendance, review }

/// State of the Create / Edit schedule wizard: a group's whole schedule in
/// one pass, Group → Working hours & break → Attendance rules → Review, and
/// one save (`PUT /schedules/groups/{groupId}`, hours and break together in
/// one transaction). Every schedule has a break; HR only chooses its length
/// and the server places it in the middle of each working day (product
/// owner, 2026-10-20; decision D28). Agreed with the product owner on 2026-10-20 instead of
/// separate Work hours and Break wizards (Figma 1365:…), so a break never
/// comes before its working hours.
///
/// The checks here only give HR quick feedback; the server validates every
/// value again and is the authority (ENGINEERING_RULES §19).
class ScheduleFormController extends ChangeNotifier {
  /// With [group], the wizard edits that group's schedule, filled in. With
  /// [groupId] only, it creates a schedule for that group, already chosen
  /// (e.g. from the group's page). With [options] already loaded, it is
  /// ready at once. With [fromGroupPage], the group step is skipped: HR
  /// opened the wizard on that group, so it starts at the working hours.
  ScheduleFormController(
    this._api, {
    required this.groups,
    GroupSchedule? group,
    ScheduleOptions? options,
    int? groupId,
    bool fromGroupPage = false,
  }) : _groupId = group?.group.id ?? groupId,
       _options = options == null ? const ScheduleOptionsLoading() : ScheduleOptionsLoaded(options),
       firstStep = fromGroupPage && (group != null || groupId != null) ? ScheduleStep.hours : ScheduleStep.group {
    if (group != null) editExisting();
    _step = firstStep;
  }

  /// Where the wizard starts, and where Back becomes Cancel.
  final ScheduleStep firstStep;

  final SchedulesApi _api;

  /// Every active group, from the Schedules list.
  final List<GroupSchedule> groups;

  ScheduleOptionsState _options;
  ScheduleOptionsState get options => _options;

  int? _groupId;
  int? get groupId => _groupId;

  /// Editing a group's schedule: the group is fixed.
  bool _editing = false;
  bool get editing => _editing;

  ScheduleStep _step = ScheduleStep.group;
  ScheduleStep get step => _step;
  bool get onLastStep => _step == ScheduleStep.review;

  final Set<int> _dayIds = {};
  Set<int> get dayIds => Set.unmodifiable(_dayIds);

  bool _sameHours = true;
  bool get sameHours => _sameHours;

  String? _start, _finish;
  String? get start => _start;
  String? get finish => _finish;

  final Map<int, ({String? start, String? finish})> _dayHours = {};

  int? _breakLength;
  int? get breakLength => _breakLength;

  String arrivalTolerance = '0';
  String leavingTolerance = '0';

  ScheduleRounding? _startRounding, _finishRounding;
  ScheduleRounding? get startRounding => _startRounding;
  ScheduleRounding? get finishRounding => _finishRounding;

  bool _submitting = false;
  bool get submitting => _submitting;

  final Map<String, ScheduleFormMessage> _fieldErrors = {};
  Map<String, ScheduleFormMessage> get fieldErrors => Map.unmodifiable(_fieldErrors);

  /// A failure not tied to a field (network, server, …).
  ApiClientException? _failure;
  ApiClientException? get failure => _failure;

  bool _disposed = false;

  /// Field names for [fieldErrors].
  static const fieldDays = 'days';
  static const fieldHours = 'hours';
  static const fieldBreak = 'break';
  static const fieldArrival = 'arrival';
  static const fieldLeaving = 'leaving';
  static const fieldForm = 'form';

  GroupSchedule? get group => groups.where((g) => g.group.id == _groupId).firstOrNull;

  /// No employee has this as their only group, so nothing can hold the
  /// schedule (Figma "blocked" 1317:742).
  bool get blocked => group?.status == GroupScheduleStatus.noSingleGroupEmployees;

  /// The group's employees have different schedules (Figma "warning" 1317:933).
  bool get employeesDiffer => group?.status == GroupScheduleStatus.employeesDiffer;

  /// Creating a schedule for a group that has one (Figma "conflict" 1317:1124).
  bool get conflict =>
      !_editing && group != null && (hasSchedule(group!, ScheduleKind.workHours) || hasSchedule(group!, ScheduleKind.breaks));

  /// Whether "Continue" may be pressed on the current step.
  bool get canContinue =>
      !_submitting &&
      switch (_step) {
        ScheduleStep.group => group != null && !blocked && !conflict && _options is ScheduleOptionsLoaded,
        ScheduleStep.hours => _dayIds.isNotEmpty,
        ScheduleStep.attendance => true,
        ScheduleStep.review => false,
      };

  bool get canSave => onLastStep && !_submitting && group != null && !blocked;

  ({String? start, String? finish}) hoursOf(int dayId) => _dayHours[dayId] ?? (start: null, finish: null);

  /// The hours of [dayId] as entered: the shared ones, or that day's.
  ({String? start, String? finish}) effectiveHoursOf(int dayId) =>
      _sameHours ? (start: _start, finish: _finish) : hoursOf(dayId);

  Future<void> loadOptions() async {
    _options = const ScheduleOptionsLoading();
    _notify();
    try {
      _options = ScheduleOptionsLoaded(await _api.options());
    } on ApiClientException catch (failure) {
      _options = ScheduleOptionsFailed(failure);
    }
    _notify();
  }

  void selectGroup(int? id) => _change(() => _groupId = id);

  void toggleDay(int dayId) => _change(() => _dayIds.contains(dayId) ? _dayIds.remove(dayId) : _dayIds.add(dayId));

  /// Selects exactly [dayIds] (the "Mon–Fri" shortcut).
  void selectDays(Iterable<int> dayIds) => _change(() => _dayIds
    ..clear()
    ..addAll(dayIds));

  void setSameHours(bool same) => _change(() => _sameHours = same);

  void setStart(String? time) => _change(() => _start = time);

  void setFinish(String? time) => _change(() => _finish = time);

  void setDayStart(int dayId, String? time) => _change(() => _dayHours[dayId] = (start: time, finish: hoursOf(dayId).finish));

  void setDayFinish(int dayId, String? time) => _change(() => _dayHours[dayId] = (start: hoursOf(dayId).start, finish: time));

  void setBreakLength(int? minutes) => _change(() => _breakLength = minutes);

  void setStartRounding(ScheduleRounding? rounding) => _change(() => _startRounding = rounding);

  void setFinishRounding(ScheduleRounding? rounding) => _change(() => _finishRounding = rounding);

  /// Goes to the next step when the current one is complete; otherwise
  /// [fieldErrors] say what is missing.
  void next() {
    final current = group;
    final loaded = _options;
    if (!canContinue || current == null || loaded is! ScheduleOptionsLoaded) return;
    _fieldErrors.clear();
    _failure = null;
    _validate(_step, loaded.options);
    if (_fieldErrors.isEmpty) _step = ScheduleStep.values[_step.index + 1];
    _notify();
  }

  void back() {
    if (_step == firstStep || _submitting) return;
    _step = ScheduleStep.values[_step.index - 1];
    _fieldErrors.clear();
    _failure = null;
    _notify();
  }

  /// Switches to editing the selected group's schedule, filled in with it.
  /// When the employees differ, the set most of them have.
  void editExisting() {
    final current = group;
    if (current == null) return;
    _editing = true;
    _dayIds.clear();
    _dayHours.clear();
    final variant = current.variants.firstOrNull;
    final days = [for (final d in variant?.workDays ?? const <WorkDaySchedule>[]) if (d.start != null && d.finish != null) d];
    for (final d in days) {
      _dayIds.add(d.day.id);
      _dayHours[d.day.id] = (start: d.start!.time, finish: d.finish!.time);
    }
    final first = days.firstOrNull;
    _start = first?.start!.time;
    _finish = first?.finish!.time;
    _sameHours = days.every((d) => d.start!.time == _start && d.finish!.time == _finish);
    arrivalTolerance = '${first?.start!.toleranceMinutes ?? 0}';
    leavingTolerance = '${first?.finish!.toleranceMinutes ?? 0}';
    _startRounding = first?.start!.rounding;
    _finishRounding = first?.finish!.rounding;
    final breaks = variant?.breaks ?? const <BreakSchedule>[];
    _breakLength = breaks.firstOrNull?.lengthMinutes;
    _change(() {});
  }

  /// Saves the whole schedule. The group's schedule as the server stored
  /// it, or `null` when it was refused ([fieldErrors] / [failure] say why,
  /// on the step concerned).
  Future<GroupSchedule?> submit() async {
    final current = group;
    final loaded = _options;
    if (current == null || loaded is! ScheduleOptionsLoaded || _submitting) return null;
    _fieldErrors.clear();
    _failure = null;
    for (final step in [ScheduleStep.hours, ScheduleStep.attendance]) {
      _validate(step, loaded.options);
      if (_fieldErrors.isNotEmpty) {
        _step = step;
        _notify();
        return null;
      }
    }

    final days = _selectedDays(loaded.options);
    _submitting = true;
    _notify();
    try {
      return await _api.setSchedule(
        current.group.id,
        SetGroupScheduleRequest(
          workHours: SetWorkHoursRequest(
            days: [
              for (final day in days)
                WorkHoursDay(dayId: day.id, start: effectiveHoursOf(day.id).start!, finish: effectiveHoursOf(day.id).finish!),
            ],
            arrivalToleranceMinutes: int.parse(arrivalTolerance.trim()),
            leavingToleranceMinutes: int.parse(leavingTolerance.trim()),
            startRounding: _startRounding,
            finishRounding: _finishRounding,
          ),
          breakMinutes: _breakLength!,
        ),
      );
    } on ApiClientException catch (failure) {
      _serverFailure(current, failure);
      return null;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  List<ScheduleDay> _selectedDays(ScheduleOptions options) => [
    for (final day in options.days) if (_dayIds.contains(day.id)) day,
  ];

  /// The checks of one step (the group and review steps have none).
  void _validate(ScheduleStep step, ScheduleOptions options) {
    final days = _selectedDays(options);
    switch (step) {
      case ScheduleStep.hours:
        if (days.isEmpty) _error(fieldDays, AdminTextKeys.scheduleErrorNoDays);
        for (final day in days) {
          final start = _minutes(effectiveHoursOf(day.id).start), finish = _minutes(effectiveHoursOf(day.id).finish);
          if (start == null || finish == null) {
            _error(fieldHours, AdminTextKeys.scheduleErrorDays);
          } else if (finish <= start) {
            _error(fieldHours, AdminTextKeys.scheduleErrorFinishBeforeStart);
          }
        }
        // The break is on the same step as the hours.
        final length = _breakLength;
        if (length == null) {
          _error(fieldBreak, AdminTextKeys.scheduleErrorBreakIncomplete);
          return;
        }
        for (final day in days) {
          final workStart = _minutes(effectiveHoursOf(day.id).start), workFinish = _minutes(effectiveHoursOf(day.id).finish);
          // Missing or wrong hours are already reported above.
          if (workStart != null && workFinish != null && length >= workFinish - workStart) {
            _error(fieldBreak, AdminTextKeys.scheduleErrorBreakOutside);
          }
        }
      case ScheduleStep.attendance:
        for (final (field, text) in [(fieldArrival, arrivalTolerance), (fieldLeaving, leavingTolerance)]) {
          final minutes = int.tryParse(text.trim());
          if (minutes == null || minutes < 0 || minutes > options.maxToleranceMinutes) {
            _error(field, AdminTextKeys.scheduleErrorTolerance, {'max': options.maxToleranceMinutes});
          }
        }
      case ScheduleStep.group || ScheduleStep.review:
    }
  }

  /// Shows a refusal from the server on the step whose field it concerns.
  void _serverFailure(GroupSchedule current, ApiClientException failure) {
    final error = failure.error;
    switch (error?.code) {
      case ApiErrorCode.validationFailed:
        final (step, field) = switch (error!.field) {
          SetWorkHoursRequest.fieldArrivalTolerance => (ScheduleStep.attendance, fieldArrival),
          SetWorkHoursRequest.fieldLeavingTolerance => (ScheduleStep.attendance, fieldLeaving),
          SetGroupScheduleRequest.fieldBreakMinutes => (ScheduleStep.hours, fieldBreak),
          _ => (ScheduleStep.hours, fieldHours),
        };
        _step = step;
        _error(field, AdminTextKeys.scheduleErrorDays);
      case ApiErrorCode.groupWithoutEmployees:
        _step = ScheduleStep.group;
        _error(fieldForm, AdminTextKeys.scheduleFormBlocked, {'group': current.group.name});
      default:
        _failure = failure;
    }
  }

  void _error(String field, String key, [Map<String, Object> args = const {}]) =>
      _fieldErrors.putIfAbsent(field, () => (key: key, args: args));

  static int? _minutes(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    return parts.length == 2 ? (int.tryParse(parts[0]) ?? -1) * 60 + (int.tryParse(parts[1]) ?? 0) : null;
  }

  void _change(VoidCallback update) {
    update();
    _fieldErrors.clear();
    _failure = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

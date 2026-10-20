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

/// State of the Create / Edit schedule wizard (Figma `HR / Schedules —
/// Create Work hours — Wizard step 1–3` 1365:2–457, `Create Break — Wizard
/// step 1–3` 1365:683–1137, `Daily hours` 1367:2): group and type, then the
/// hours (or break details), then attendance rules (or the break review).
///
/// The checks here only give HR quick feedback; the server validates every
/// value again and is the authority (ENGINEERING_RULES §19).
class ScheduleFormController extends ChangeNotifier {
  /// With [group] and [kind], the form edits that schedule. With [options]
  /// already loaded, the form is ready at once.
  ScheduleFormController(
    this._api, {
    required this.groups,
    GroupSchedule? group,
    ScheduleKind? kind,
    ScheduleOptions? options,
  }) : _groupId = group?.group.id,
       _kind = kind ?? ScheduleKind.workHours,
       _options = options == null ? const ScheduleOptionsLoading() : ScheduleOptionsLoaded(options) {
    if (group != null && kind != null) editExisting();
  }

  final SchedulesApi _api;

  /// Every active group, from the Schedules list.
  final List<GroupSchedule> groups;

  ScheduleOptionsState _options;
  ScheduleOptionsState get options => _options;

  int? _groupId;
  int? get groupId => _groupId;

  ScheduleKind _kind;
  ScheduleKind get kind => _kind;

  /// Editing an existing schedule: group and type are fixed.
  bool _editing = false;
  bool get editing => _editing;

  final Set<int> _dayIds = {};
  Set<int> get dayIds => Set.unmodifiable(_dayIds);

  bool _sameHours = true;
  bool get sameHours => _sameHours;

  String? _start, _finish;
  String? get start => _start;
  String? get finish => _finish;

  final Map<int, ({String? start, String? finish})> _dayHours = {};

  String arrivalTolerance = '0';
  String leavingTolerance = '0';

  ScheduleRounding? _startRounding, _finishRounding;
  ScheduleRounding? get startRounding => _startRounding;
  ScheduleRounding? get finishRounding => _finishRounding;

  String? _breakStart;
  String? get breakStart => _breakStart;
  int? _breakLength;
  int? get breakLength => _breakLength;

  /// The wizard step: 0 group & type, 1 hours or break details, 2 attendance
  /// rules or review.
  int _step = 0;
  int get step => _step;
  static const lastStep = 2;
  bool get onLastStep => _step == lastStep;

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
  static const fieldArrival = 'arrival';
  static const fieldLeaving = 'leaving';
  static const fieldBreak = 'break';
  static const fieldForm = 'form';

  /// Times offered in the time pickers: every 5 minutes, the smallest
  /// rounding interval. A saved time between steps is offered as well.
  static final timeChoices = [
    for (var minutes = 0; minutes < 24 * 60; minutes += 5)
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
  ];

  GroupSchedule? get group => groups.where((g) => g.group.id == _groupId).firstOrNull;

  /// No employee has this as their only group, so nothing can hold the
  /// schedule (Figma "Create Work hours — blocked" 1317:742).
  bool get blocked => group?.status == GroupScheduleStatus.noSingleGroupEmployees;

  /// The group's employees have different schedules (Figma "warning" 1317:933).
  bool get employeesDiffer => group?.status == GroupScheduleStatus.employeesDiffer;

  /// A break for a group without work hours: a break must fall within the
  /// working day, so the work hours come first (server: "The break must fall
  /// within the working hours").
  bool get breaksNeedHours {
    final current = group;
    if (current == null || _kind != ScheduleKind.breaks || blocked) return false;
    return current.status != GroupScheduleStatus.configured || current.variants.single.workDays.isEmpty;
  }

  /// Creating what the group already has (Figma "conflict" 1317:1124).
  bool get conflict => !_editing && group != null && hasSchedule(group!, _kind);

  /// A group and at least one day are still missing.
  bool get missingRequired => group == null || _dayIds.isEmpty;

  /// Whether "Continue" may be pressed on the current step.
  bool get canContinue => switch (_step) {
    0 => group != null && !blocked && !conflict && !breaksNeedHours && _options is ScheduleOptionsLoaded,
    1 => _dayIds.isNotEmpty,
    _ => false,
  } && !_submitting;

  bool get canSave =>
      !missingRequired && !blocked && !conflict && !_submitting && _options is ScheduleOptionsLoaded;

  ({String? start, String? finish}) hoursOf(int dayId) => _dayHours[dayId] ?? (start: null, finish: null);

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

  void selectKind(ScheduleKind kind) => _change(() => _kind = kind);

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

  void setStartRounding(ScheduleRounding? rounding) => _change(() => _startRounding = rounding);

  void setFinishRounding(ScheduleRounding? rounding) => _change(() => _finishRounding = rounding);

  void setBreakStart(String? time) => _change(() => _breakStart = time);

  void setBreakLength(int? minutes) => _change(() => _breakLength = minutes);

  /// Goes to the next step when the current one is complete; otherwise
  /// [fieldErrors] say what is missing.
  void next() {
    final current = group;
    final loaded = _options;
    if (!canContinue || current == null || loaded is! ScheduleOptionsLoaded) return;
    _fieldErrors.clear();
    _failure = null;
    _validateStep(_step, current, loaded.options, _selectedDays(loaded.options));
    if (_fieldErrors.isEmpty) _step++;
    _notify();
  }

  void back() {
    if (_step == 0 || _submitting) return;
    _step--;
    _fieldErrors.clear();
    _failure = null;
    _notify();
  }

  List<ScheduleDay> _selectedDays(ScheduleOptions options) => [
    for (final day in options.days) if (_dayIds.contains(day.id)) day,
  ];

  /// Switches to editing what the selected group has of [kind], filled in
  /// with it. When the employees differ, the set most of them have.
  void editExisting() {
    final current = group;
    if (current == null) return;
    _editing = true;
    _dayIds.clear();
    _dayHours.clear();
    final variant = current.variants.firstOrNull;
    switch (_kind) {
      case ScheduleKind.workHours:
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
      case ScheduleKind.breaks:
        final breaks = variant?.breaks ?? const <BreakSchedule>[];
        _dayIds.addAll(breaks.map((b) => b.day.id));
        _breakStart = breaks.firstOrNull?.usualStart;
        _breakLength = breaks.firstOrNull?.lengthMinutes;
    }
    _change(() {});
  }

  /// Saves the schedule. The group's schedule as the server stored it, or
  /// `null` when it was refused ([fieldErrors] / [failure] say why).
  Future<GroupSchedule?> submit() async {
    final current = group;
    final loaded = _options;
    if (current == null || loaded is! ScheduleOptionsLoaded || !canSave) return null;
    _fieldErrors.clear();
    _failure = null;
    final days = _selectedDays(loaded.options);
    for (final step in [1, 2]) {
      _validateStep(step, current, loaded.options, days);
      if (_fieldErrors.isNotEmpty) {
        _step = step;
        _notify();
        return null;
      }
    }

    _submitting = true;
    _notify();
    try {
      return switch (_kind) {
        ScheduleKind.workHours => await _api.setWorkHours(
          current.group.id,
          SetWorkHoursRequest(
            days: [
              for (final day in days) WorkHoursDay(dayId: day.id, start: _startOf(day.id)!, finish: _finishOf(day.id)!),
            ],
            arrivalToleranceMinutes: int.parse(arrivalTolerance.trim()),
            leavingToleranceMinutes: int.parse(leavingTolerance.trim()),
            startRounding: _startRounding,
            finishRounding: _finishRounding,
          ),
        ),
        ScheduleKind.breaks => await _api.setBreaks(
          current.group.id,
          SetBreaksRequest(
            days: [for (final day in days) BreakDay(dayId: day.id, usualStart: _breakStart!, lengthMinutes: _breakLength!)],
          ),
        ),
      };
    } on ApiClientException catch (failure) {
      _serverFailure(current, failure);
      return null;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  String? _startOf(int dayId) => _sameHours ? _start : hoursOf(dayId).start;
  String? _finishOf(int dayId) => _sameHours ? _finish : hoursOf(dayId).finish;

  /// The checks of one wizard step (step 0 has none: its choices are menus).
  void _validateStep(int step, GroupSchedule current, ScheduleOptions options, List<ScheduleDay> days) {
    if (step == 1 && days.isEmpty) _error(fieldDays, AdminTextKeys.scheduleErrorNoDays);
    switch ((_kind, step)) {
      case (ScheduleKind.workHours, 1):
        for (final day in days) {
          final start = _minutes(_startOf(day.id)), finish = _minutes(_finishOf(day.id));
          if (start == null || finish == null) {
            _error(fieldHours, AdminTextKeys.scheduleErrorDays);
          } else if (finish <= start) {
            _error(fieldHours, AdminTextKeys.scheduleErrorFinishBeforeStart);
          }
        }
      case (ScheduleKind.workHours, 2):
        for (final (field, text) in [(fieldArrival, arrivalTolerance), (fieldLeaving, leavingTolerance)]) {
          final minutes = int.tryParse(text.trim());
          if (minutes == null || minutes < 0 || minutes > options.maxToleranceMinutes) {
            _error(field, AdminTextKeys.scheduleErrorTolerance, {'max': options.maxToleranceMinutes});
          }
        }
      case (ScheduleKind.breaks, 1):
        final start = _minutes(_breakStart), length = _breakLength;
        if (start == null || length == null) {
          _error(fieldBreak, AdminTextKeys.scheduleErrorDays);
          return;
        }
        if (current.status != GroupScheduleStatus.configured || current.variants.single.workDays.isEmpty) {
          _error(fieldBreak, AdminTextKeys.scheduleErrorBreaksNeedHours, {'group': current.group.name});
          return;
        }
        final hours = {for (final d in current.variants.single.workDays) d.day.id: d};
        for (final day in days) {
          final work = hours[day.id];
          final workStart = _minutes(work?.start?.time), workFinish = _minutes(work?.finish?.time);
          if (workStart == null || workFinish == null || start < workStart || start + length > workFinish) {
            _error(fieldBreak, AdminTextKeys.scheduleErrorBreakOutside);
          }
        }
      default:
    }
  }

  /// Shows a refusal from the server on the step whose field it concerns.
  void _serverFailure(GroupSchedule current, ApiClientException failure) {
    final error = failure.error;
    if (error?.code == ApiErrorCode.validationFailed) {
      _step = switch (error!.field) {
        SetWorkHoursRequest.fieldArrivalTolerance || SetWorkHoursRequest.fieldLeavingTolerance => 2,
        _ => 1,
      };
    }
    switch (error?.code) {
      case ApiErrorCode.validationFailed:
        _error(switch (error!.field) {
          SetWorkHoursRequest.fieldArrivalTolerance => fieldArrival,
          SetWorkHoursRequest.fieldLeavingTolerance => fieldLeaving,
          _ when _kind == ScheduleKind.breaks => fieldBreak,
          _ => fieldHours,
        }, AdminTextKeys.scheduleErrorDays);
      case ApiErrorCode.groupWithoutEmployees:
        _error(fieldForm, AdminTextKeys.scheduleFormBlocked, {'group': current.group.name});
      case ApiErrorCode.scheduleEmployeesDiffer:
        _error(fieldForm, AdminTextKeys.scheduleErrorBreaksNeedHours, {'group': current.group.name});
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

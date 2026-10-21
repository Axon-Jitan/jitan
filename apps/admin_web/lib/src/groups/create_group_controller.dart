import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_form_controller.dart';
import 'group_name_error.dart';

/// The steps of Create group, in order.
enum CreateGroupStep { details, employees, hours }

/// State of Create group (Figma `HR / Employee groups — Create group`,
/// steps 1–3): the name, the employees from every company, and the work
/// hours and break, sent in **one** request that the server saves in one
/// transaction (`POST /groups`).
///
/// Every group has work hours (product owner, 2026-10-21). They are kept on
/// the employees whose only group is the new one, so step 2 needs at least
/// one of them. The checks here only give HR quick feedback; the server
/// checks everything again and is the authority.
class CreateGroupController extends ChangeNotifier {
  CreateGroupController({required this._groupsApi, required this._schedulesApi});

  final GroupManagementApi _groupsApi;
  final SchedulesApi _schedulesApi;

  static final _time = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  CreateGroupStep _step = CreateGroupStep.details;
  CreateGroupStep get step => _step;

  String _name = '';
  String get name => _name;

  /// A text key under the name field.
  String? _nameError;
  String? get nameError => _nameError;

  Map<int, GroupMember> _selected = const {};
  Map<int, GroupMember> get selected => _selected;

  ScheduleOptionsState _options = const ScheduleOptionsLoading();
  ScheduleOptionsState get options => _options;
  bool _optionsRequested = false;

  final Set<int> _dayIds = {};
  Set<int> get dayIds => Set.unmodifiable(_dayIds);

  bool _sameHours = true;
  bool get sameHours => _sameHours;

  String? _start, _finish;
  String? get start => _start;
  String? get finish => _finish;
  final Map<int, ({String? start, String? finish})> _dayHours = {};

  String _breakText = '';
  String get breakText => _breakText;

  bool _submitting = false;
  bool get submitting => _submitting;

  /// A refusal shown on the current step.
  ApiClientException? _failure;
  ApiClientException? get failure => _failure;

  bool _disposed = false;

  /// The chosen employees in no other group: the work hours are kept on them.
  int get onlyHereCount => _selected.values.where((m) => m.groups.isEmpty).length;

  bool get canContinue => switch (_step) {
    CreateGroupStep.details => _name.trim().isNotEmpty,
    CreateGroupStep.employees => onlyHereCount > 0,
    CreateGroupStep.hours => false,
  };

  bool get canSubmit =>
      _step == CreateGroupStep.hours && !_submitting && _hoursComplete && hoursErrorKey == null && breakErrorKey == null;

  ({String? start, String? finish}) hoursOf(int dayId) =>
      _sameHours ? (start: _start, finish: _finish) : _dayHours[dayId] ?? (start: null, finish: null);

  /// "Finish must be after the start", once both times of a day are typed.
  String? get hoursErrorKey {
    for (final dayId in _dayIds) {
      final (:start, :finish) = hoursOf(dayId);
      final from = _minutes(start), to = _minutes(finish);
      if (from != null && to != null && to <= from) return AdminTextKeys.groupsErrorFinishBeforeStart;
    }
    return null;
  }

  /// The break must be one of the allowed lengths and shorter than every
  /// working day.
  String? get breakErrorKey {
    if (_breakText.trim().isEmpty) return null;
    final minutes = int.tryParse(_breakText.trim());
    final loaded = _options;
    if (minutes == null || (loaded is ScheduleOptionsLoaded && !loaded.options.breakLengthMinutes.contains(minutes))) {
      return AdminTextKeys.groupsErrorBreakLength;
    }
    for (final dayId in _dayIds) {
      final (:start, :finish) = hoursOf(dayId);
      final from = _minutes(start), to = _minutes(finish);
      if (from != null && to != null && to > from && minutes >= to - from) return AdminTextKeys.scheduleErrorBreakOutside;
    }
    return null;
  }

  /// The allowed break lengths, for the error text.
  List<int> get breakLengths => switch (_options) {
    ScheduleOptionsLoaded(:final options) => options.breakLengthMinutes,
    _ => const [],
  };

  bool get _hoursComplete =>
      _dayIds.isNotEmpty &&
      _dayIds.every((id) => _minutes(hoursOf(id).start) != null && _minutes(hoursOf(id).finish) != null) &&
      int.tryParse(_breakText.trim()) != null;

  void setName(String name) => _change(() {
    _name = name;
    _nameError = null;
  });

  void setSelected(Map<int, GroupMember> selected) => _change(() => _selected = Map.unmodifiable(selected));

  void toggleDay(int dayId) => _change(() => _dayIds.contains(dayId) ? _dayIds.remove(dayId) : _dayIds.add(dayId));

  void selectDays(Iterable<int> dayIds) => _change(() => _dayIds
    ..clear()
    ..addAll(dayIds));

  void setSameHours(bool same) => _change(() {
    // Switching to hours per day starts every day from the shared hours.
    if (!same) {
      for (final id in _dayIds) {
        _dayHours.putIfAbsent(id, () => (start: _start, finish: _finish));
      }
    }
    _sameHours = same;
  });

  void setStart(String? time) => _change(() => _start = time);

  void setFinish(String? time) => _change(() => _finish = time);

  void setDayStart(int dayId, String? time) =>
      _change(() => _dayHours[dayId] = (start: time, finish: _dayHours[dayId]?.finish));

  void setDayFinish(int dayId, String? time) =>
      _change(() => _dayHours[dayId] = (start: _dayHours[dayId]?.start, finish: time));

  void setBreak(String text) => _change(() => _breakText = text);

  /// Step 1 → 2 → 3; the name is checked before leaving step 1.
  void next() {
    switch (_step) {
      case CreateGroupStep.details:
        final problem = groupNameProblem(_name);
        if (problem != null) {
          _nameError = problem;
        } else {
          _step = CreateGroupStep.employees;
        }
      case CreateGroupStep.employees:
        if (onlyHereCount == 0) return;
        _step = CreateGroupStep.hours;
        if (!_optionsRequested) loadOptions();
      case CreateGroupStep.hours:
        return;
    }
    _failure = null;
    _notify();
  }

  void back() {
    if (_submitting || _step == CreateGroupStep.details) return;
    _step = CreateGroupStep.values[_step.index - 1];
    _failure = null;
    _notify();
  }

  /// The days, and the allowed break lengths, from the server.
  Future<void> loadOptions() async {
    _optionsRequested = true;
    _options = const ScheduleOptionsLoading();
    _notify();
    try {
      _options = ScheduleOptionsLoaded(await _schedulesApi.options());
    } on ApiClientException catch (failure) {
      _options = ScheduleOptionsFailed(failure);
    }
    _notify();
  }

  /// Creates the group with its employees and work hours; the group as the
  /// server stored it, or `null` when refused (shown on the step concerned).
  Future<GroupOverview?> submit() async {
    final loaded = _options;
    if (!canSubmit || loaded is! ScheduleOptionsLoaded) return null;
    _submitting = true;
    _failure = null;
    _notify();
    try {
      return await _groupsApi.create(
        CreateGroupRequest(
          name: _name.trim(),
          employeeIds: _selected.keys.toList(),
          schedule: SetGroupScheduleRequest(
            workHours: SetWorkHoursRequest(
              days: [
                for (final day in loaded.options.days)
                  if (_dayIds.contains(day.id))
                    WorkHoursDay(dayId: day.id, start: hoursOf(day.id).start!, finish: hoursOf(day.id).finish!),
              ],
              arrivalToleranceMinutes: 0,
              leavingToleranceMinutes: 0,
            ),
            breakMinutes: int.parse(_breakText.trim()),
          ),
        ),
      );
    } on ApiClientException catch (failure) {
      _refused(failure);
      return null;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  /// Takes HR back to the step a refusal is about.
  void _refused(ApiClientException failure) {
    final error = failure.error;
    if (groupNameErrorKey(failure) case final key?) {
      _step = CreateGroupStep.details;
      _nameError = key;
    } else if (error?.code == ApiErrorCode.groupWithoutEmployees || error?.field == CreateGroupRequest.fieldEmployeeIds) {
      _step = CreateGroupStep.employees;
      _failure = failure;
    } else {
      _failure = failure;
    }
  }

  static int? _minutes(String? time) {
    final match = time == null ? null : _time.firstMatch(time);
    return match == null ? null : int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  void _change(VoidCallback update) {
    update();
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import 'schedule_rows.dart';

/// What the Schedules screen is showing.
sealed class SchedulesState {
  const SchedulesState();
}

class SchedulesLoading extends SchedulesState {
  const SchedulesLoading();
}

class SchedulesLoaded extends SchedulesState {
  const SchedulesLoaded(this.groups);

  /// Every active group with what the server found, including groups with
  /// no schedule (the form's group choices).
  final List<GroupSchedule> groups;
}

class SchedulesFailed extends SchedulesState {
  const SchedulesFailed(this.failure);

  final ApiClientException failure;
}

/// Loads the groups' schedules and filters the rows for display.
///
/// Holds no schedule rules: the server derives each group's schedule and
/// validates every change; this sequences requests and filters what is shown.
class SchedulesController extends ChangeNotifier {
  SchedulesController(this._api);

  final SchedulesApi _api;

  SchedulesState _state = const SchedulesLoading();
  SchedulesState get state => _state;

  ScheduleFilter _filter = const ScheduleFilter();
  ScheduleFilter get filter => _filter;

  /// The form's choices, loaded with the list so "Add schedule" opens
  /// complete; `null` until loaded (the form then loads them itself).
  ScheduleOptions? _options;
  ScheduleOptions? get options => _options;

  int _latestRequest = 0;
  bool _disposed = false;

  /// Every row, before filtering; empty unless loaded.
  List<ScheduleRow> get allRows => switch (_state) {
    SchedulesLoaded(:final groups) => scheduleRowsOf(groups),
    _ => const [],
  };

  List<ScheduleRow> get visibleRows => allRows.where(_filter.matches).toList();

  Future<void> load() async {
    final request = ++_latestRequest;
    _emit(const SchedulesLoading());
    if (_options == null) unawaited(_loadOptions());
    try {
      final groups = await _api.groupSchedules();
      if (request == _latestRequest) _emit(SchedulesLoaded(groups));
    } on ApiClientException catch (failure) {
      if (request == _latestRequest) _emit(SchedulesFailed(failure));
    }
  }

  Future<void> _loadOptions() async {
    try {
      _options = await _api.options();
    } on ApiClientException {
      // The form shows its own loading and error state instead.
    }
  }

  void updateFilter(ScheduleFilter filter) {
    _filter = filter;
    if (!_disposed) notifyListeners();
  }

  /// Switches the [row]'s schedule off for the group's employees; the
  /// failure, or `null` once the server confirmed (the list then reloads).
  Future<ApiClientException?> deactivate(ScheduleRow row) async {
    try {
      switch (row.kind) {
        case ScheduleKind.workHours:
          await _api.removeWorkHours(row.group.id);
        case ScheduleKind.breaks:
          await _api.removeBreaks(row.group.id);
      }
    } on ApiClientException catch (failure) {
      return failure;
    }
    await load();
    return null;
  }

  void _emit(SchedulesState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

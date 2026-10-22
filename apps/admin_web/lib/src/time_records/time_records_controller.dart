import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// The periods HR can pick (Figma `160:2` "Period").
enum TimeRecordPeriod { thisWeek, lastWeek, thisMonth, lastMonth }

sealed class TimeRecordsState {
  const TimeRecordsState();
}

class TimeRecordsLoading extends TimeRecordsState {
  const TimeRecordsLoading();
}

class TimeRecordsLoaded extends TimeRecordsState {
  const TimeRecordsLoaded(this.days);

  final List<TimeRecordDay> days;
}

class TimeRecordsFailed extends TimeRecordsState {
  const TimeRecordsFailed(this.failure);

  final ApiClientException failure;
}

/// Loads Time records for the chosen company (or every company), period and
/// employee search. The status filter only narrows what is loaded; the
/// server calculates every status.
class TimeRecordsController extends ChangeNotifier {
  TimeRecordsController(this._api, {DateTime Function()? today, this.searchDelay = const Duration(milliseconds: 300)})
    : _today = today ?? DateTime.now;

  final TimeRecordsApi _api;
  final DateTime Function() _today;
  final Duration searchDelay;

  TimeRecordsState _state = const TimeRecordsLoading();
  TimeRecordsState get state => _state;

  int? _companyId;
  int? get companyId => _companyId;
  String _search = '';
  TimeRecordPeriod _period = TimeRecordPeriod.thisWeek;
  TimeRecordPeriod get period => _period;
  TimeRecordStatus? _status;
  TimeRecordStatus? get status => _status;

  Timer? _searchTimer;
  int _request = 0;
  bool _disposed = false;

  /// The days the status filter lets through.
  List<TimeRecordDay> get visibleDays => switch (_state) {
    TimeRecordsLoaded(:final days) => [for (final d in days) if (_status == null || d.status == _status) d],
    _ => const [],
  };

  /// Every day loaded for the period, whatever the status filter.
  int get loadedCount => switch (_state) {
    TimeRecordsLoaded(:final days) => days.length,
    _ => 0,
  };

  bool get isFiltered => _companyId != null || _search.isNotEmpty || _period != TimeRecordPeriod.thisWeek || _status != null;

  Future<void> load() async {
    final request = ++_request;
    _emit(const TimeRecordsLoading());
    final (from, to) = rangeOf(_period, _today());
    try {
      final days = await _api.list(from: from, to: to, companyId: _companyId, search: _search);
      if (request == _request) _emit(TimeRecordsLoaded(days));
    } on ApiClientException catch (failure) {
      if (request == _request) _emit(TimeRecordsFailed(failure));
    }
  }

  void selectCompany(int? id) {
    if (id == _companyId) return;
    _companyId = id;
    load();
  }

  void selectPeriod(TimeRecordPeriod period) {
    if (period == _period) return;
    _period = period;
    load();
  }

  void selectStatus(TimeRecordStatus? status) {
    _status = status;
    _emit(_state);
  }

  void updateSearch(String text) {
    final search = text.trim();
    if (search == _search) return;
    _search = search;
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDelay, load);
  }

  /// "Reset all": every company, this week, all statuses, no search.
  void resetAll() {
    _searchTimer?.cancel();
    _companyId = null;
    _search = '';
    _period = TimeRecordPeriod.thisWeek;
    _status = null;
    load();
  }

  /// The first and last calendar day of [period] around [today] (weeks start
  /// on Monday).
  static (DateTime, DateTime) rangeOf(TimeRecordPeriod period, DateTime today) {
    final day = DateTime.utc(today.year, today.month, today.day);
    final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    return switch (period) {
      TimeRecordPeriod.thisWeek => (monday, monday.add(const Duration(days: 6))),
      TimeRecordPeriod.lastWeek => (monday.subtract(const Duration(days: 7)), monday.subtract(const Duration(days: 1))),
      TimeRecordPeriod.thisMonth => (DateTime.utc(day.year, day.month), DateTime.utc(day.year, day.month + 1, 0)),
      TimeRecordPeriod.lastMonth => (DateTime.utc(day.year, day.month - 1), DateTime.utc(day.year, day.month, 0)),
    };
  }

  void _emit(TimeRecordsState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    super.dispose();
  }
}

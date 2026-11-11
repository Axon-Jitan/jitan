import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../period/chosen_period.dart';

/// What the Reports page is showing.
sealed class ReportsState {
  const ReportsState();
}

class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

class ReportsLoaded extends ReportsState {
  const ReportsLoaded(this.report);

  final HoursReport report;
}

class ReportsFailed extends ReportsState {
  const ReportsFailed(this.failure);

  final ApiClientException failure;
}

/// Loads a period's report and filters it by name or code. Every number comes
/// from the server; here they are only added up for what is on screen. The
/// period is remembered in this browser, like the Dashboard's.
class ReportsController extends ChangeNotifier {
  ReportsController(this._api, this._store, {required DateTime today})
    : _period = ChosenPeriod.decode(_store.read(_storeKey), today, byDefault: PeriodPreset.thisMonth);

  static const _storeKey = 'jitan.reports.period';

  final ReportsApi _api;
  final SessionStore _store;

  ReportsState _state = const ReportsLoading();
  ReportsState get state => _state;

  ChosenPeriod _period;
  ChosenPeriod get period => _period;

  int? _companyId;
  int? get companyId => _companyId;

  String _search = '';
  int _latestRequest = 0;
  bool _disposed = false;

  List<HoursReportEmployee> get visible => switch (_state) {
    ReportsLoaded(:final report) => [
      for (final employee in report.employees)
        if (_matches(employee)) employee,
    ],
    _ => const [],
  };

  bool _matches(HoursReportEmployee employee) {
    if (_search.isEmpty) return true;
    final text = '${employee.firstName ?? ''} ${employee.lastName ?? ''} ${employee.code}';
    return text.toLowerCase().contains(_search.toLowerCase());
  }

  Future<void> load() async {
    final request = ++_latestRequest;
    _emit(const ReportsLoading());
    try {
      final report = await _api.hours(_period.from, _period.to, companyId: _companyId);
      if (request == _latestRequest) _emit(ReportsLoaded(report));
    } on ApiClientException catch (failure) {
      if (request == _latestRequest) _emit(ReportsFailed(failure));
    }
  }

  void updatePeriod(ChosenPeriod period) {
    _period = period;
    _store.write(_storeKey, period.encode());
    load();
  }

  void updateCompany(int? companyId) {
    _companyId = companyId;
    load();
  }

  void updateSearch(String text) {
    _search = text.trim();
    _notify();
  }

  void _emit(ReportsState state) {
    _state = state;
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

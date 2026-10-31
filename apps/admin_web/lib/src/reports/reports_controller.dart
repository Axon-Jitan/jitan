import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

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

/// Loads a month's report and filters it by name or code. Every number comes
/// from the server; here they are only added up for what is on screen.
class ReportsController extends ChangeNotifier {
  ReportsController(this._api, {required this._month});

  final ReportsApi _api;

  ReportsState _state = const ReportsLoading();
  ReportsState get state => _state;

  String _month;
  String get month => _month;

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
      final report = await _api.hours(_month, companyId: _companyId);
      if (request == _latestRequest) _emit(ReportsLoaded(report));
    } on ApiClientException catch (failure) {
      if (request == _latestRequest) _emit(ReportsFailed(failure));
    }
  }

  void updateMonth(String month) {
    _month = month;
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

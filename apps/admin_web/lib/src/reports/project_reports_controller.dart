import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What the Projects view of Reports is showing.
sealed class ProjectReportsState {
  const ProjectReportsState();
}

class ProjectReportsLoading extends ProjectReportsState {
  const ProjectReportsLoading();
}

class ProjectReportsLoaded extends ProjectReportsState {
  const ProjectReportsLoaded(this.report);

  final ProjectReport report;
}

class ProjectReportsFailed extends ProjectReportsState {
  const ProjectReportsFailed(this.failure);

  final ApiClientException failure;
}

/// Loads a month's project report and filters it by SAP number or name.
/// Every number comes from the server; here they are only added up for what
/// is on screen.
class ProjectReportsController extends ChangeNotifier {
  ProjectReportsController(this._api, {required this._month});

  final ReportsApi _api;

  ProjectReportsState _state = const ProjectReportsLoading();
  ProjectReportsState get state => _state;

  String _month;
  String get month => _month;

  String _search = '';
  int _latestRequest = 0;
  bool _disposed = false;

  /// The SAP number starts the name, so one search finds both.
  List<ProjectReportProject> get visible => switch (_state) {
    ProjectReportsLoaded(:final report) => [
      for (final project in report.projects)
        if (_search.isEmpty || project.project.fullName.toLowerCase().contains(_search.toLowerCase())) project,
    ],
    _ => const [],
  };

  Future<void> load() async {
    final request = ++_latestRequest;
    _emit(const ProjectReportsLoading());
    try {
      final report = await _api.projects(_month);
      if (request == _latestRequest) _emit(ProjectReportsLoaded(report));
    } on ApiClientException catch (failure) {
      if (request == _latestRequest) _emit(ProjectReportsFailed(failure));
    }
  }

  void updateMonth(String month) {
    _month = month;
    load();
  }

  void updateSearch(String text) {
    _search = text.trim();
    _notify();
  }

  void _emit(ProjectReportsState state) {
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

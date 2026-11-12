import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What the Projects page is showing.
sealed class ProjectsState {
  const ProjectsState();
}

class ProjectsLoading extends ProjectsState {
  const ProjectsLoading();
}

class ProjectsLoaded extends ProjectsState {
  const ProjectsLoaded(this.projects);

  final List<ProjectSummary> projects;
}

class ProjectsFailed extends ProjectsState {
  const ProjectsFailed(this.failure);

  final ApiClientException failure;
}

/// The status filter of the list; `null` = all.
enum ProjectStatusFilter { active, inactive }

/// Loads the projects and filters them for display. Holds no project rules:
/// the server validates every change.
class ProjectsController extends ChangeNotifier {
  ProjectsController(this._api);

  final ProjectsApi _api;

  ProjectsState _state = const ProjectsLoading();
  ProjectsState get state => _state;

  String _search = '';
  String get search => _search;

  ProjectStatusFilter? _status;
  ProjectStatusFilter? get status => _status;

  bool _disposed = false;

  List<ProjectSummary> get all => switch (_state) {
    ProjectsLoaded(:final projects) => projects,
    _ => const [],
  };

  /// Searched by SAP number, name and place, and by status.
  List<ProjectSummary> get visible => [
    for (final project in all)
      if ((_search.isEmpty || '${project.fullName} ${project.placeName ?? ''}'.toLowerCase().contains(_search.toLowerCase())) &&
          switch (_status) {
            null => true,
            ProjectStatusFilter.active => project.isActive,
            ProjectStatusFilter.inactive => !project.isActive,
          })
        project,
  ];

  Future<void> load() async {
    if (_state is! ProjectsLoaded) _emit(const ProjectsLoading());
    try {
      _emit(ProjectsLoaded(await _api.list()));
    } on ApiClientException catch (failure) {
      _emit(ProjectsFailed(failure));
    }
  }

  void updateSearch(String text) {
    _search = text.trim();
    _notify();
  }

  void updateStatus(ProjectStatusFilter? status) {
    _status = status;
    _notify();
  }

  void _emit(ProjectsState state) {
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

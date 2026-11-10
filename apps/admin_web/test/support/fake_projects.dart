import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import 'fake_locations.dart';

/// A project as the server describes it: a client site in Mouscron, or (with
/// [workshopId]) internal work there.
ProjectDetails projectDetails({
  int id = 3,
  String sapNumber = 'P-1042',
  String name = 'Office refurbishment',
  bool active = true,
  int? workshopId,
  DateTime? lastUsed,
}) => ProjectDetails(
  summary: ProjectSummary(
    id: id,
    sapNumber: sapNumber,
    name: name,
    isClientSite: workshopId == null,
    isActive: active,
    placeName: workshopId == null ? 'Mouscron' : 'Almeco workshop',
    lastUsed: lastUsed,
  ),
  site: workshopId == null ? location(id, '$sapNumber $name') : null,
  workshopId: workshopId,
);

/// Stand-in for [ProjectsApi]: an in-memory list; every call is recorded.
class FakeProjectsApi implements ProjectsApi {
  List<ProjectDetails> projects = [];
  final calls = <String>[];
  final saved = <ProjectRequest>[];
  ApiClientException? fail;

  @override
  Future<List<ProjectSummary>> list() async {
    if (fail case final failure?) throw failure;
    return [for (final p in projects) p.summary];
  }

  @override
  Future<ProjectDetails> find(int projectId) async => projects.firstWhere((p) => p.summary.id == projectId);

  @override
  Future<ProjectDetails> create(ProjectRequest request) async {
    calls.add('create');
    saved.add(request);
    final created = projectDetails(id: 9, sapNumber: request.sapNumber, name: request.name, workshopId: request.workshopId);
    projects = [...projects, created];
    return created;
  }

  @override
  Future<ProjectDetails> update(int projectId, ProjectRequest request) async {
    calls.add('update $projectId');
    saved.add(request);
    return find(projectId);
  }

  @override
  Future<ProjectDetails> deactivate(int projectId) async {
    calls.add('deactivate $projectId');
    return _setActive(projectId, active: false);
  }

  @override
  Future<ProjectDetails> reactivate(int projectId) async {
    calls.add('reactivate $projectId');
    return _setActive(projectId, active: true);
  }

  ProjectDetails _setActive(int projectId, {required bool active}) {
    final current = projects.firstWhere((p) => p.summary.id == projectId);
    final changed = projectDetails(
      id: projectId,
      sapNumber: current.summary.sapNumber,
      name: current.summary.name,
      active: active,
      workshopId: current.workshopId,
    );
    projects = [for (final p in projects) p.summary.id == projectId ? changed : p];
    return changed;
  }
}

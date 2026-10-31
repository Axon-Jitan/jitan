import 'package:jitan_api/src/database/sql_executor.dart';
import 'package:jitan_api/src/projects/project_repository.dart';
import 'package:jitan_models/jitan_models.dart';

/// Projects in memory, with the proposed lookup rows.
class FakeProjectRepository implements ProjectRepository {
  static const client = ProjectChoice(id: 1, name: 'Client');
  static const internal = ProjectChoice(id: 2, name: 'Internal');
  static const planned = ProjectChoice(id: 1, name: 'Planned');
  static const active = ProjectChoice(id: 2, name: 'Active');

  final projects = <int, ({int companyId, ProjectRequest request})>{};

  /// (userId, projectId) → link.
  final linksRows = <(int, int), ({int id, bool current})>{};
  var _nextProject = 1;
  var _nextLink = 1;

  Map<int, String> companyNames = {7: 'Almeco', 8: 'PCA'};
  Map<int, ProjectEmployee> employees = {};

  ProjectSummary _summary(int id) {
    final (:companyId, :request) = projects[id]!;
    return ProjectSummary(
      id: id,
      name: request.name,
      reference: request.reference,
      companyId: companyId,
      companyName: companyNames[companyId] ?? '',
      type: request.typeId == client.id ? client : internal,
      status: request.statusId == planned.id ? planned : active,
      teamSize: linksRows.entries.where((e) => e.key.$2 == id && e.value.current).length,
    );
  }

  @override
  Future<List<ProjectChoice>> types(SqlExecutor executor) async => const [client, internal];

  @override
  Future<List<ProjectChoice>> statuses(SqlExecutor executor) async => const [planned, active];

  @override
  Future<List<ProjectSummary>> list(SqlExecutor executor, List<int> companyIds) async => [
    for (final MapEntry(key: id, value: p) in projects.entries)
      if (companyIds.contains(p.companyId)) _summary(id),
  ];

  @override
  Future<ProjectDetails?> find(SqlExecutor executor, int companyId, int projectId) async {
    final project = projects[projectId];
    if (project == null || project.companyId != companyId) return null;
    return ProjectDetails(
      summary: _summary(projectId),
      startDate: DateTime.parse('${project.request.startDate}T00:00:00Z'),
      addressId: project.request.addressId,
      employees: [
        for (final MapEntry(:key, :value) in linksRows.entries)
          if (key.$2 == projectId && value.current)
            employees[key.$1] ?? ProjectEmployee(id: key.$1, code: 'U${key.$1}'),
      ],
    );
  }

  @override
  Future<bool> lock(SqlExecutor tx, int companyId, int projectId) async => projects[projectId]?.companyId == companyId;

  @override
  Future<int> insert(SqlExecutor tx, int companyId, ProjectRequest project) async {
    final id = _nextProject++;
    projects[id] = (companyId: companyId, request: project);
    return id;
  }

  @override
  Future<void> update(SqlExecutor tx, int projectId, ProjectRequest project) async {
    projects[projectId] = (companyId: projects[projectId]!.companyId, request: project);
  }

  @override
  Future<Map<int, ({int id, bool current})>> links(SqlExecutor tx, int projectId) async => {
    for (final MapEntry(:key, :value) in linksRows.entries)
      if (key.$2 == projectId) key.$1: value,
  };

  @override
  Future<int> addLink(SqlExecutor tx, int userId, int projectId) async {
    final id = _nextLink++;
    linksRows[(userId, projectId)] = (id: id, current: true);
    return id;
  }

  @override
  Future<void> setLink(SqlExecutor tx, int userProjectId, {required bool current}) async {
    final key = linksRows.entries.firstWhere((e) => e.value.id == userProjectId).key;
    linksRows[key] = (id: userProjectId, current: current);
  }
}

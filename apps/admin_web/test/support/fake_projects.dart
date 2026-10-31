import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

const client = ProjectChoice(id: 1, name: 'Client');
const internal = ProjectChoice(id: 2, name: 'Internal');
const planned = ProjectChoice(id: 1, name: 'Planned');
const active = ProjectChoice(id: 2, name: 'Active');

ProjectDetails projectDetails({
  int id = 3,
  String name = 'Office refurbishment',
  int companyId = 7,
  String companyName = 'Almeco',
  ProjectChoice type = internal,
  ProjectChoice status = active,
  String? reference = 'PRJ-001',
  int? addressId,
  String? addressName,
  List<ProjectEmployee> employees = const [],
}) => ProjectDetails(
  summary: ProjectSummary(
    id: id,
    name: name,
    reference: reference,
    companyId: companyId,
    companyName: companyName,
    type: type,
    status: status,
    teamSize: employees.length,
  ),
  startDate: DateTime.utc(2026, 10, 19),
  addressId: addressId,
  addressName: addressName,
  employees: employees,
);

/// Stand-in for [ProjectsApi].
class FakeProjectsApi implements ProjectsApi {
  List<ProjectDetails> projects = [];
  ApiClientException? fail;
  final created = <(int, ProjectRequest)>[];
  final updated = <(int, int, ProjectRequest)>[];
  final assigned = <(int, int, List<int>)>[];

  @override
  Future<ProjectOptions> options() async =>
      const ProjectOptions(types: [client, internal], statuses: [planned, active], addressTypeIds: [1]);

  @override
  Future<List<ProjectSummary>> list() async {
    if (fail case final failure?) throw failure;
    return [for (final p in projects) p.summary];
  }

  @override
  Future<ProjectDetails> find(int companyId, int projectId) async {
    if (fail case final failure?) throw failure;
    return projects.firstWhere((p) => p.summary.id == projectId);
  }

  @override
  Future<ProjectDetails> create(int companyId, ProjectRequest request) async {
    if (fail case final failure?) throw failure;
    created.add((companyId, request));
    final project = projectDetails(id: projects.length + 100, name: request.name, companyId: companyId);
    projects.add(project);
    return project;
  }

  @override
  Future<ProjectDetails> update(int companyId, int projectId, ProjectRequest request) async {
    if (fail case final failure?) throw failure;
    updated.add((companyId, projectId, request));
    return projectDetails(id: projectId, name: request.name, companyId: companyId);
  }

  @override
  Future<ProjectDetails> assign(int companyId, int projectId, List<int> employeeIds) async {
    if (fail case final failure?) throw failure;
    assigned.add((companyId, projectId, employeeIds));
    return projectDetails(
      id: projectId,
      companyId: companyId,
      employees: [for (final id in employeeIds) ProjectEmployee(id: id, code: 'U$id')],
    );
  }
}

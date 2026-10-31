import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin managing projects.
class ProjectsApi {
  const ProjectsApi(this._transport);

  final ApiTransport _transport;

  Future<ProjectOptions> options() async {
    final json = await _transport.getJson('project-options');
    try {
      return ProjectOptions.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Project options: ${e.message}');
    }
  }

  /// Every project the viewer may see.
  Future<List<ProjectSummary>> list() async {
    final json = await _transport.getJson('projects');
    try {
      return ProjectListResponse.fromJson(json).projects;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Projects: ${e.message}');
    }
  }

  Future<ProjectDetails> find(int companyId, int projectId) async =>
      _details(await _transport.getJson('companies/$companyId/projects/$projectId'));

  Future<ProjectDetails> create(int companyId, ProjectRequest request) async =>
      _details(await _transport.postJson('companies/$companyId/projects', request.toJson()));

  Future<ProjectDetails> update(int companyId, int projectId, ProjectRequest request) async =>
      _details(await _transport.putJson('companies/$companyId/projects/$projectId', request.toJson()));

  /// "Save assignments": [employeeIds] become the project's team.
  Future<ProjectDetails> assign(int companyId, int projectId, List<int> employeeIds) async => _details(
    await _transport.putJson(
      'companies/$companyId/projects/$projectId/employees',
      ProjectEmployeesRequest(employeeIds: employeeIds).toJson(),
    ),
  );

  static ProjectDetails _details(Map<String, Object?> json) {
    try {
      return ProjectDetails.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Project: ${e.message}');
    }
  }
}

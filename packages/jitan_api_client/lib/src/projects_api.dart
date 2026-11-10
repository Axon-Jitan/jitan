import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin managing projects (D43, D44): shared by every company, so the
/// paths have none.
class ProjectsApi {
  const ProjectsApi(this._transport);

  final ApiTransport _transport;

  /// Every project, active or not.
  Future<List<ProjectSummary>> list() async {
    final json = await _transport.getJson('projects');
    try {
      return ProjectListResponse.fromJson(json).projects;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Projects: ${e.message}');
    }
  }

  Future<ProjectDetails> find(int projectId) async => _details(await _transport.getJson('projects/$projectId'));

  Future<ProjectDetails> create(ProjectRequest request) async => _details(await _transport.postJson('projects', request.toJson()));

  Future<ProjectDetails> update(int projectId, ProjectRequest request) async =>
      _details(await _transport.putJson('projects/$projectId', request.toJson()));

  Future<ProjectDetails> deactivate(int projectId) async =>
      _details(await _transport.postJson('projects/$projectId/deactivate', const {}));

  Future<ProjectDetails> reactivate(int projectId) async =>
      _details(await _transport.postJson('projects/$projectId/reactivate', const {}));

  static ProjectDetails _details(Map<String, Object?> json) {
    try {
      return ProjectDetails.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Project: ${e.message}');
    }
  }
}

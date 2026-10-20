import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin managing employee groups: every group with its number of
/// employees, add, rename, deactivate and reactivate. (Picking an assignable
/// group is `GroupsApi`.)
class GroupManagementApi {
  const GroupManagementApi(this._transport);

  final ApiTransport _transport;

  /// Every group, active or not, with its number of employees.
  Future<List<GroupOverview>> overview() async {
    final json = await _transport.getJson('groups/overview');
    try {
      return GroupOverviewListResponse.fromJson(json).groups;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Group overview: ${e.message}');
    }
  }

  Future<GroupOverview> create(String name) async =>
      _group(await _transport.postJson('groups', GroupNameRequest(name: name).toJson()));

  Future<GroupOverview> rename(int groupId, String name) async =>
      _group(await _transport.putJson('groups/$groupId', GroupNameRequest(name: name).toJson()));

  Future<GroupOverview> deactivate(int groupId) async =>
      _group(await _transport.postJson('groups/$groupId/deactivate', const {}));

  Future<GroupOverview> reactivate(int groupId) async =>
      _group(await _transport.postJson('groups/$groupId/reactivate', const {}));

  static GroupOverview _group(Map<String, Object?> json) {
    try {
      return GroupOverview.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Group: ${e.message}');
    }
  }
}

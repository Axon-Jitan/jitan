import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin managing who is in a group, from every company (groups are
/// shared by all companies): `GET /groups/{id}/members`, `…/candidates`,
/// `POST …/members`, `DELETE …/members/{userId}`. Each write answers with
/// the group's members as they are afterwards.
class GroupMembersApi {
  const GroupMembersApi(this._transport);

  final ApiTransport _transport;

  Future<List<GroupMember>> members(int groupId) async => _list(await _transport.getJson('groups/$groupId/members'));

  /// Employees not yet in the group, matching [search] on name or code.
  Future<List<GroupMember>> candidates(int groupId, {String? search}) async => _list(
        await _transport.getJson(
          'groups/$groupId/candidates',
          query: {if (search != null && search.trim().isNotEmpty) 'search': search.trim()},
        ),
      );

  Future<List<GroupMember>> add(int groupId, List<int> userIds) async =>
      _list(await _transport.postJson('groups/$groupId/members', AddAssignmentsRequest(ids: userIds).toJson()));

  Future<List<GroupMember>> remove(int groupId, int userId) async =>
      _list(await _transport.deleteJson('groups/$groupId/members/$userId'));

  static List<GroupMember> _list(Map<String, Object?> json) {
    try {
      return GroupMemberListResponse.fromJson(json).members;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Group members: ${e.message}');
    }
  }
}

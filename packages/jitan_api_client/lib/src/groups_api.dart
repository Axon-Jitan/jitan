import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `/groups`: assignable employee groups (e.g. Blue/White collar).
class GroupsApi {
  const GroupsApi(this._transport);

  final ApiTransport _transport;

  Future<List<GroupSummary>> listGroups() async {
    final json = await _transport.getJson('groups');
    try {
      return GroupListResponse.fromJson(json).groups;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Group list: ${e.message}');
    }
  }
}

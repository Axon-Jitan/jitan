import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin: the fixed lists Jitan reads by name (the Lists page).
class FixedListsApi {
  const FixedListsApi(this._transport);

  final ApiTransport _transport;

  Future<FixedListOverview> overview() async => _overview(await _transport.getJson('lists'));

  Future<FixedListDetail> detail(FixedListKind kind) async => _detail(await _transport.getJson('lists/${kind.wireName}'));

  /// Adds what [kind] misses; returns the list as the server has it now.
  Future<FixedListDetail> addMissing(FixedListKind kind) async =>
      _detail(await _transport.postJson('lists/${kind.wireName}/add-missing', const {}));

  /// "Add what's missing": every list at once.
  Future<FixedListOverview> addAllMissing() async => _overview(await _transport.postJson('lists/add-missing', const {}));

  static FixedListOverview _overview(Map<String, Object?> json) {
    try {
      return FixedListOverview.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Lists: ${e.message}');
    }
  }

  static FixedListDetail _detail(Map<String, Object?> json) {
    try {
      return FixedListDetail.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'List: ${e.message}');
    }
  }
}

import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// The signed-in employee's activity, projects and companies.
class ActivityApi {
  const ActivityApi(this._transport);

  final ApiTransport _transport;

  Future<MyActivity> mine() async => _activity(await _transport.getJson('me/activity'));

  /// Switches what the time counts for; the workday goes on.
  Future<MyActivity> switchTo(SwitchActivityRequest request) async =>
      _activity(await _transport.postJson('me/activity', request.toJson()));

  static MyActivity _activity(Map<String, Object?> json) {
    try {
      return MyActivity.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Activity: ${e.message}');
    }
  }
}

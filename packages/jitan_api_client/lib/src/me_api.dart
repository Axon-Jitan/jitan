import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `GET /me`: the signed-in employee. Needs a session (see
/// [ApiTransport.accessToken]); a 401 means the session is no longer valid.
class MeApi {
  const MeApi(this._transport);

  final ApiTransport _transport;

  Future<EmployeeAccount> me() async {
    final json = await _transport.getJson('me');
    try {
      return EmployeeAccount.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Me: ${e.message}');
    }
  }
}

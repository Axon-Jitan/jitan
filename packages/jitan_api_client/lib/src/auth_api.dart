import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `POST /auth/sign-in`: employee code + password for an activated employee
/// (new device, reinstall, expired session, sign-out). Fails with
/// `invalid_credentials` (deliberately generic) or `account_inactive`.
class AuthApi {
  const AuthApi(this._transport);

  final ApiTransport _transport;

  Future<SessionResponse> signIn(SignInRequest request) async {
    final json = await _transport.postJson('auth/sign-in', request.toJson());
    try {
      return SessionResponse.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Sign-in: ${e.message}');
    }
  }
}

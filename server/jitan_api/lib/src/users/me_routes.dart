import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/request_identity.dart';
import '../http/api_exception.dart';
import '../http/json_response.dart';
import 'user_repository.dart';

/// `GET /me`: the signed-in employee. Any signed-in user may read their own
/// account, so this needs an identity but no permission. Consumer: the
/// Employee app's Ready/Home screen right after onboarding (ONB-02).
class MeRoutes {
  const MeRoutes(this._users);

  final UserRepository _users;

  Router get router => Router()..get('/me', _me);

  Future<Response> _me(Request request) async {
    final account = await _users.account(request.identity.userId) ??
        (throw const ApiException.unauthenticated('The session is not valid. Sign in again.'));
    return jsonResponse(account.toJson()).change(headers: const {'cache-control': 'no-store'});
  }
}

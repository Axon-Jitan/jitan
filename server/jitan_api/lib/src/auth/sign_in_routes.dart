import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import 'sign_in_service.dart';

/// `POST /auth/sign-in` (public: this is how a device gets a session).
/// Consumer: the Employee app's "Auth / 01 Sign in" screen.
class SignInRoutes {
  const SignInRoutes(this._signIn);

  final SignInService _signIn;

  Router get router => Router()..post('/auth/sign-in', _post);

  Future<Response> _post(Request request) async {
    final SignInRequest body;
    try {
      body = SignInRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    final result = await _signIn.signIn(body);
    return jsonResponse(result.toJson()).change(headers: const {'cache-control': 'no-store'});
  }
}

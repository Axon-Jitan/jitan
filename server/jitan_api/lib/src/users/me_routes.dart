import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/request_identity.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import 'account_service.dart';
import 'user_repository.dart';

/// The signed-in employee's own account. Needs an identity but no
/// permission: everyone may act on their own account. Consumer: the
/// Employee app (Home, Profile).
///
/// - `GET /me`: the account
/// - `POST /me/password` with a `ChangePasswordRequest`: new password; the
///   response is a new session for this device (all others end)
/// - `GET /me/terminal-qr`: the employee's Terminal QR (`TerminalQr`, My QR)
///   with `cache-control: no-store`; 404 when the account has none
class MeRoutes {
  const MeRoutes(this._users, this._accounts);

  final UserRepository _users;
  final AccountService _accounts;

  Router get router => Router()
    ..get('/me', _me)
    ..post('/me/password', _changePassword)
    ..get('/me/terminal-qr', _terminalQr);

  Future<Response> _terminalQr(Request request) async {
    final qrCode = await _users.terminalQr(request.identity.userId) ??
        (throw const ApiException.notFound('This account has no Terminal QR.'));
    return jsonResponse(TerminalQr(qrCode: qrCode).toJson()).change(headers: const {'cache-control': 'no-store'});
  }

  Future<Response> _changePassword(Request request) async {
    final ChangePasswordRequest body;
    try {
      body = ChangePasswordRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    final result = await _accounts.changePassword(request.identity, body);
    return jsonResponse(result.toJson()).change(headers: const {'cache-control': 'no-store'});
  }

  Future<Response> _me(Request request) async {
    final account = await _users.account(request.identity.userId) ??
        (throw const ApiException.unauthenticated('The session is not valid. Sign in again.'));
    return jsonResponse(account.toJson()).change(headers: const {'cache-control': 'no-store'});
  }
}

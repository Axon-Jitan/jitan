import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import 'recovery_service.dart';

/// Password recovery endpoints. Consumer: the employee app's Sign in →
/// Recover account flow. **No sign-in**: the employee is locked out; the
/// temporary recovery QR is the credential.
///
/// - `POST /recovery/start` `{qrCode}` → the account
/// - `POST /recovery/complete` `{qrCode, password, deviceId}` → new password
///   set **and** this device signed in
class RecoveryRoutes {
  const RecoveryRoutes(this._recovery);

  final RecoveryService _recovery;

  Router get router => Router()
    ..post('/recovery/start', _start)
    ..post('/recovery/complete', _complete);

  Future<Response> _start(Request request) async {
    final body = await _read(request, RecoveryStartRequest.fromJson);
    return _noStore((await _recovery.start(body.qrCode)).toJson());
  }

  Future<Response> _complete(Request request) async {
    final body = await _read(request, RecoveryCompleteRequest.fromJson);
    return _noStore((await _recovery.complete(body)).toJson());
  }

  static Future<T> _read<T>(Request request, T Function(Map<String, Object?>) fromJson) async {
    try {
      return fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }

  /// Responses carry a session token: never cached.
  static Response _noStore(Map<String, Object?> body) =>
      jsonResponse(body).change(headers: const {'cache-control': 'no-store'});
}

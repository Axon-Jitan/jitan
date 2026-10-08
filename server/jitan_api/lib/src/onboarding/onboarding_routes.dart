import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import 'onboarding_service.dart';

/// Onboarding endpoints. Consumer: the Employee app's onboarding flow
/// (ONB-02). **No sign-in**: the employee has no password yet; the scanned
/// temporary onboarding QR is the credential.
///
/// - `POST /onboarding/start` `{qrCode}` → the account to confirm
/// - `POST /onboarding/complete` `{qrCode, password, deviceId, languageCode?}`
///   → onboarding completed **and** this device signed in (session token)
class OnboardingRoutes {
  const OnboardingRoutes(this._onboarding);

  final OnboardingService _onboarding;

  Router get router => Router()
    ..post('/onboarding/start', _start)
    ..post('/onboarding/complete', _complete);

  Future<Response> _start(Request request) async {
    final body = await _read(request, OnboardingStartRequest.fromJson);
    return _noStore((await _onboarding.start(body.qrCode)).toJson());
  }

  Future<Response> _complete(Request request) async {
    final body = await _read(request, OnboardingCompleteRequest.fromJson);
    return _noStore((await _onboarding.complete(body)).toJson());
  }

  static Future<T> _read<T>(Request request, T Function(Map<String, Object?>) fromJson) async {
    try {
      return fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }

  /// Responses can carry a session token: never cached.
  static Response _noStore(Map<String, Object?> body) =>
      jsonResponse(body).change(headers: const {'cache-control': 'no-store'});
}

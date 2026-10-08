import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `/onboarding/*`: used by the Employee app's onboarding flow (ONB-02).
/// No sign-in; the scanned temporary onboarding QR is the credential.
class OnboardingApi {
  const OnboardingApi(this._transport);

  final ApiTransport _transport;

  /// The account behind a scanned temporary onboarding QR, for the employee
  /// to confirm. Fails with e.g. `onboarding_already_completed`,
  /// `qr_expired`, `qr_already_used`, `qr_wrong_purpose`.
  Future<EmployeeAccount> start(String qrCode) async {
    final json = await _transport.postJson('onboarding/start', OnboardingStartRequest(qrCode: qrCode).toJson());
    return _decode('Onboarding account', () => EmployeeAccount.fromJson(json));
  }

  /// Sets the mandatory first password, which completes onboarding, and
  /// returns the session for this device: no separate sign-in follows.
  Future<SessionResponse> complete(OnboardingCompleteRequest request) async {
    final json = await _transport.postJson('onboarding/complete', request.toJson());
    return _decode('Onboarding result', () => SessionResponse.fromJson(json));
  }

  static T _decode<T>(String what, T Function() decode) {
    try {
      return decode();
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, '$what: ${e.message}');
    }
  }
}

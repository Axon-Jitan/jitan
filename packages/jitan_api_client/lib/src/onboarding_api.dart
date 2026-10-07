import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `/onboarding/*`: used by the Employee app's onboarding flow (ONB-02).
/// No sign-in; the scanned personal QR is the credential.
class OnboardingApi {
  const OnboardingApi(this._transport);

  final ApiTransport _transport;

  /// The account behind a scanned QR, for the employee to confirm.
  ///
  /// Fails with `onboarding_already_completed` once a password is set: the
  /// same QR then only works at Jitan Terminal.
  Future<OnboardingAccount> start(String qrCode) =>
      _account(_transport.postJson('onboarding/start', OnboardingStartRequest(qrCode: qrCode).toJson()));

  /// Sets the first password, which completes onboarding.
  Future<OnboardingAccount> complete(String qrCode, String password) => _account(_transport.postJson(
        'onboarding/complete',
        OnboardingCompleteRequest(qrCode: qrCode, password: password).toJson(),
      ));

  static Future<OnboardingAccount> _account(Future<Map<String, Object?>> request) async {
    final json = await request;
    try {
      return OnboardingAccount.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Onboarding account: ${e.message}');
    }
  }
}

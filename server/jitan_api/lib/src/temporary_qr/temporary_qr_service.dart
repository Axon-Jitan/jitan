import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';
import 'temporary_qr_tokens.dart';
import 'temporary_token_store.dart';

/// Temporary QRs for onboarding and password recovery (IT decision
/// 2026-10-08, GAP-04): issue, check on scan, and redeem exactly once.
///
/// Redeeming spans two systems that cannot commit together (MySQL and the
/// temporary store), so it runs as claim → [redeem]'s work → consume:
/// - the claim makes the scanning device the only one that can complete;
/// - if the work is refused, the claim is released;
/// - if anything fails after the work committed (the store, the network),
///   the **same device** retrying with the same QR is let through again
///   (`isRetry`), and the work must then finish idempotently (e.g. check the
///   password it already stored instead of storing another). Any other
///   device is refused (`qr_already_used`).
class TemporaryQrService {
  TemporaryQrService({required this._tokens, required this._store});

  final TemporaryQrTokens _tokens;
  final TemporaryTokenStore _store;

  /// A new QR for [userId] and [purpose]; the previous one stops working.
  Future<IssuedTemporaryQr> issue(int userId, TemporaryQrPurpose purpose) async {
    final issued = _tokens.issue(userId, purpose);
    await _store.replace(_key(issued.claims), issued.claims.tokenId, issued.claims.expiresAt);
    return issued;
  }

  /// Checks a scanned [qrCode] for [purpose] without using it: signature,
  /// purpose, expiry, still the current QR and unused.
  Future<TemporaryQrClaims> check(String qrCode, TemporaryQrPurpose purpose) async {
    final claims = _verified(qrCode, purpose);
    _requireUsable(await _store.inspect(_key(claims), claims.tokenId), retryAllowed: false);
    return claims;
  }

  /// Runs [work] holding the QR for [deviceId] and consumes the QR when it
  /// succeeds. See the class documentation for failures and retries.
  Future<T> redeem<T>(
    String qrCode,
    TemporaryQrPurpose purpose,
    String deviceId,
    Future<T> Function(TemporaryQrClaims claims, {required bool isRetry}) work,
  ) async {
    final claims = _verified(qrCode, purpose);
    final key = _key(claims);
    final state = await _store.claim(key, claims.tokenId, deviceId);
    _requireUsable(state, retryAllowed: true);
    final isRetry = state != TemporaryTokenState.available;

    final T result;
    try {
      result = await work(claims, isRetry: isRetry);
    } on ApiException {
      // A definite refusal: nothing was written, the QR may be used again.
      if (!isRetry) await _store.release(key, claims.tokenId, deviceId);
      rethrow;
    }
    await _store.consume(key, claims.tokenId, deviceId);
    return result;
  }

  TemporaryQrClaims _verified(String qrCode, TemporaryQrPurpose purpose) {
    final claims = switch (_tokens.check(qrCode.trim())) {
      ValidTemporaryQr(:final claims) => claims,
      ExpiredTemporaryQr(:final claims) when claims.purpose != purpose => throw _wrongPurpose(),
      ExpiredTemporaryQr() => throw _expired(),
      InvalidTemporaryQr() => throw const ApiException(400, ApiErrorCode.invalidQrCode, 'This is not a valid Jitan QR code.'),
    };
    if (claims.purpose != purpose) throw _wrongPurpose();
    return claims;
  }

  static void _requireUsable(TemporaryTokenState state, {required bool retryAllowed}) {
    switch (state) {
      case TemporaryTokenState.available:
        return;
      case TemporaryTokenState.claimedByThisDevice || TemporaryTokenState.consumedByThisDevice when retryAllowed:
        return;
      case TemporaryTokenState.unknown:
        throw _expired();
      case TemporaryTokenState.claimedByThisDevice ||
            TemporaryTokenState.consumedByThisDevice ||
            TemporaryTokenState.usedElsewhere:
        throw const ApiException(409, ApiErrorCode.qrAlreadyUsed, 'This QR code was already used.');
    }
  }

  static TemporaryTokenKey _key(TemporaryQrClaims claims) => (userId: claims.userId, purpose: claims.purpose);

  static ApiException _expired() =>
      const ApiException(410, ApiErrorCode.qrExpired, 'This QR code is no longer valid. Ask HR/Admin for a new one.');

  static ApiException _wrongPurpose() =>
      const ApiException(400, ApiErrorCode.qrWrongPurpose, 'This QR code is meant for something else.');
}

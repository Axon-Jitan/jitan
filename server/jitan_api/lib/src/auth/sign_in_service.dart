import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../users/user_repository.dart';
import 'credential_repository.dart';
import 'device_id.dart';
import 'password_hasher.dart';
import 'password_policy.dart';
import 'session_tokens.dart';

/// Sign-in with employee code + password, for an activated employee on a new
/// device, after a reinstall, an expired session or sign-out. Onboarding
/// does not use this: it signs the device in itself.
///
/// Never reveals whether a code exists: an unknown code, a wrong password
/// and an employee who never set a password all get the same
/// `invalid_credentials`, after the same Argon2id work. Only with the
/// correct password does an inactive or MFD account get
/// `account_inactive` ("Account unavailable").
class SignInService {
  SignInService({
    required this._credentials,
    required this._users,
    required this._executor,
    required this._sessions,
    this._hasher = const PasswordHasher(),
  });

  final CredentialRepository _credentials;
  final UserRepository _users;
  final SqlExecutor _executor;
  final SessionTokens _sessions;
  final PasswordHasher _hasher;

  /// Longest accepted employee code, as a cheap sanity bound.
  static const maxCodeLength = 64;

  /// Verified when no account matches, so a missing code costs the same time
  /// as a wrong password. Its password is unknowable (random salt + hash).
  static Future<String>? _decoyHash;

  Future<SessionResponse> signIn(SignInRequest request) async {
    final code = request.code.trim();
    if (code.isEmpty || code.length > maxCodeLength) throw _invalidCredentials();
    if (request.password.isEmpty || request.password.length > PasswordPolicy.maxLength) throw _invalidCredentials();
    final deviceId = checkedDeviceId(request.deviceId, field: SignInRequest.fieldDeviceId);

    final candidates = await _credentials.candidatesByCode(_executor, code);
    if (candidates.isEmpty) {
      await _hasher.verify(request.password, await (_decoyHash ??= _hasher.hash('decoy-${DateTime.now()}')));
      throw _invalidCredentials();
    }
    for (final candidate in candidates) {
      if (!await _hasher.verify(request.password, candidate.passwordHash)) continue;
      if (!candidate.isActive || candidate.isMarkedForDeletion) {
        throw const ApiException(403, ApiErrorCode.accountInactive, 'This account can’t sign in right now.');
      }
      final account = await _users.account(candidate.userId) ?? (throw _invalidCredentials());
      final session = _sessions.issue(userId: candidate.userId, deviceId: deviceId, passwordHash: candidate.passwordHash);
      return SessionResponse(
        account: account,
        session: SessionInfo(accessToken: session.token, expiresAt: session.expiresAt),
      );
    }
    throw _invalidCredentials();
  }

  static ApiException _invalidCredentials() =>
      const ApiException(401, ApiErrorCode.invalidCredentials, 'The employee code or password is incorrect.');
}

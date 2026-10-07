import 'package:shelf/shelf.dart';

import '../http/api_exception.dart';
import '../users/user_repository.dart';
import 'request_identity.dart';
import 'session_tokens.dart';

/// Authenticates `Authorization: Bearer <session token>` requests.
///
/// A token is accepted only if its signature and expiry are valid **and** the
/// user is still active, not deleted, and has the same password as when the
/// token was issued (a password change ends every session). Anything else is
/// 401: an invalid token never falls back to another mechanism.
///
/// Requests without an Authorization header pass through unchanged.
class TokenAuthenticationMiddleware {
  const TokenAuthenticationMiddleware({required this.tokens, required this.users});

  final SessionTokens tokens;
  final UserRepository users;

  static const _scheme = 'bearer ';

  Middleware get middleware => (inner) => (request) async {
        final header = request.headers['authorization'];
        if (header == null) return inner(request);
        if (!header.toLowerCase().startsWith(_scheme)) throw _unauthenticated();

        final claims = tokens.verify(header.substring(_scheme.length).trim());
        if (claims == null) throw _unauthenticated();

        final passwordHash = await users.activePasswordHash(claims.userId);
        if (passwordHash == null || tokens.passwordFingerprint(passwordHash) != claims.passwordFingerprint) {
          throw _unauthenticated();
        }
        return inner(request.withIdentity(RequestIdentity(userId: claims.userId, deviceId: claims.deviceId)));
      };

  static ApiException _unauthenticated() =>
      const ApiException.unauthenticated('The session is not valid. Sign in again.');
}

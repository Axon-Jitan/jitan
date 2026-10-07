import 'package:shelf/shelf.dart';

import '../http/api_exception.dart';

/// The authenticated user making a request.
///
/// Produced by an authentication mechanism (a session token, or the
/// development identity) and consumed by authorization and services.
/// Endpoints depend only on this type, so the mechanism can change without
/// endpoint changes.
class RequestIdentity {
  const RequestIdentity({required this.userId, this.deviceId});

  /// `tblUser.userID` of the acting user.
  final int userId;

  /// The device of the session, when authenticated with a session token.
  final String? deviceId;
}

const _contextKey = 'jitan.identity';

extension RequestIdentityAccess on Request {
  /// Returns a request carrying [identity] for downstream handlers.
  Request withIdentity(RequestIdentity identity) => change(context: {_contextKey: identity});

  /// Whether an authentication mechanism already identified the user.
  bool get hasIdentity => context[_contextKey] is RequestIdentity;

  /// The acting user. Throws 401 when no authentication mechanism attached one.
  RequestIdentity get identity {
    final identity = context[_contextKey];
    if (identity is RequestIdentity) return identity;
    throw const ApiException.unauthenticated('Sign in to use this resource.');
  }
}

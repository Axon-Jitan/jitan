import 'package:shelf/shelf.dart';

import '../http/api_exception.dart';

/// The authenticated user making a request.
///
/// Produced by an authentication mechanism (today: the development identity;
/// later: real login) and consumed by authorization and services. Endpoints
/// depend only on this type, so swapping the mechanism needs no endpoint change.
class RequestIdentity {
  const RequestIdentity({required this.userId});

  /// `tblUser.userID` of the acting user.
  final int userId;
}

const _contextKey = 'jitan.identity';

extension RequestIdentityAccess on Request {
  /// Returns a request carrying [identity] for downstream handlers.
  Request withIdentity(RequestIdentity identity) => change(context: {_contextKey: identity});

  /// The acting user. Throws 401 when no authentication mechanism attached one.
  RequestIdentity get identity {
    final identity = context[_contextKey];
    if (identity is RequestIdentity) return identity;
    throw const ApiException.unauthenticated('Sign in to use this resource.');
  }
}

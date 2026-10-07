import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import '../config/app_environment.dart';
import '../http/api_exception.dart';
import '../users/user_repository.dart';
import 'request_identity.dart';

final _log = Logger('auth.dev_identity');

/// DEVELOPMENT ONLY: treats every request without a session token as coming
/// from `JITAN_DEV_USER_ID`. A request already authenticated with a session
/// token keeps that identity.
///
/// Replaces authentication only. The user must still exist and be active,
/// exactly as real authentication will require, and authorization still runs.
/// Refuses to be constructed in production, on top of the startup check in
/// `AppConfig`.
class DevelopmentIdentityMiddleware {
  DevelopmentIdentityMiddleware({
    required AppEnvironment environment,
    required this.devUserId,
    required this.users,
  }) {
    if (!environment.allowsDevelopmentMechanisms) {
      throw StateError('The development identity cannot be used in ${environment.name}.');
    }
    _log.warning('Development identity ACTIVE: every request acts as tblUser.userID=$devUserId.');
  }

  final int devUserId;
  final UserRepository users;

  Middleware get middleware => (inner) => (request) async {
        if (request.hasIdentity) return inner(request);
        if (!await users.isActiveUser(devUserId)) {
          throw ApiException.unauthenticated(
            'JITAN_DEV_USER_ID=$devUserId is not an active, non-deleted user in tblUser.',
          );
        }
        return inner(request.withIdentity(RequestIdentity(userId: devUserId)));
      };
}

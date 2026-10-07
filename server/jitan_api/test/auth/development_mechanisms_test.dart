import 'package:jitan_api/src/auth/development_identity_middleware.dart';
import 'package:jitan_api/src/auth/development_permission_evaluator.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/auth/request_identity.dart';
import 'package:jitan_api/src/auth/unconfigured_permission_evaluator.dart';
import 'package:jitan_api/src/config/app_environment.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

void main() {
  group('development mechanisms cannot be built in production', () {
    test('development identity', () {
      expect(
        () => DevelopmentIdentityMiddleware(
          environment: AppEnvironment.production,
          devUserId: 1,
          users: FakeUserRepository({1}),
        ),
        throwsStateError,
      );
    });

    test('development permissions', () {
      expect(() => DevelopmentPermissionEvaluator(AppEnvironment.production), throwsStateError);
    });
  });

  test('development permissions allow in development', () async {
    final evaluator = DevelopmentPermissionEvaluator(AppEnvironment.development);
    expect(
      await evaluator.isAllowed(const RequestIdentity(userId: 1), Permission.viewCompanies),
      isTrue,
    );
  });

  test('the unconfigured production evaluator denies everything', () async {
    const evaluator = UnconfiguredPermissionEvaluator();
    for (final permission in Permission.values) {
      expect(await evaluator.isAllowed(const RequestIdentity(userId: 1), permission), isFalse);
    }
  });
}

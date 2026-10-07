@Tags(['integration'])
library;

import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/database/database_exception.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// The connection pool against real MySQL.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;

  // One connection: a single leaked connection would block everything after.
  setUp(() => db = TestDatabase.connect(maxConnections: 1));
  tearDown(() => db.close());

  test('failed transactions return their connection to the pool', () async {
    for (var i = 0; i < 3; i++) {
      await expectLater(
        db.transaction((tx) async {
          await tx.query('SELECT 1 AS one');
          throw StateError('fails on purpose');
        }),
        throwsStateError,
      );
      await expectLater(
        db.transaction((tx) => tx.query('SELECT no_such_column FROM tblCompany')),
        throwsA(isA<DatabaseQueryException>()),
      );
    }

    final rows = await db.query('SELECT 1 AS one').timeout(const Duration(seconds: 5));
    expect(rows.single.readInt('one'), 1);
  });

  test('a successful transaction returns its result', () async {
    expect(await db.transaction((tx) async => (await tx.query('SELECT 2 AS two')).single.readInt('two')), 2);
  });
}

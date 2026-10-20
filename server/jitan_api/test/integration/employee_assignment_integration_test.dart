@Tags(['integration'])
library;

import 'package:jitan_api/src/audit/audit_log_repository.dart';
import 'package:jitan_api/src/companies/company_repository.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/employees/employee_assignment_repository.dart';
import 'package:jitan_api/src/employees/employee_assignment_service.dart';
import 'package:jitan_api/src/employees/employee_repository.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/languages/language_repository.dart';
import 'package:jitan_api/src/languages/user_language_repository.dart';
import 'package:jitan_api/src/languages/user_language_service.dart';
import 'package:jitan_api/src/onboarding/onboarding_repository.dart';
import 'package:jitan_api/src/schedules/employee_schedule_sync.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Employee assignments against real MySQL with `[DEV-TEST]` fixtures,
/// removed in tearDownAll.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  final stamp = DateTime.now().microsecondsSinceEpoch % 100000000;
  final companyIds = <String, int>{};
  final groupIds = <String, int>{};
  final credGroupIds = <String, int>{};
  final languageIds = <String, int>{};
  final languageCodes = <String, String>{};

  /// A unique code that fits `tblLanguage.languageCode` (VARCHAR(10) in IT's database).
  String languageCode() => 't${languageCodes.length}${stamp % 1000000}';
  late int userId;
  late int actorId;
  final extraUserIds = <int>[];
  final eventTypeIds = <int>[];
  const repo = EmployeeAssignmentRepository();

  EmployeeAssignmentService service() => EmployeeAssignmentService(
    assignments: repo,
    employees: EmployeeRepository(db),
    companies: CompanyRepository(db),
    audit: const AuditLogRepository(),
    transactions: db,
    executor: db,
    userLanguages: const UserLanguageRepository(),
    languageChanges: UserLanguageService(
      userLanguages: const UserLanguageRepository(),
      employees: EmployeeRepository(db),
      audit: const AuditLogRepository(),
      transactions: db,
    ),
    scheduleSync: const EmployeeScheduleSync(),
  );

  Future<int> insertCompany(String key, {required bool active, bool mfd = false}) async {
    final id = (await db.execute(
      'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:name, :active, :mfd)',
      {'name': '[DEV-TEST] $key $stamp', 'active': active, 'mfd': mfd},
    )).lastInsertId;
    return companyIds[key] = id;
  }

  Future<int> insertGroup(String key, {required bool active, bool mfd = false}) async {
    final id = (await db.execute(
      'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:name, :active, :mfd)',
      {'name': '[DEV-TEST] $key $stamp', 'active': active, 'mfd': mfd},
    )).lastInsertId;
    return groupIds[key] = id;
  }

  Future<int> insertCredGroup(String key, {required bool active, bool mfd = false}) async {
    final id = (await db.execute(
      'INSERT INTO tblCredGroup (credGroupName, credGroupLevel, credGroupActive, credGroupMFD) '
      'VALUES (:name, 99, :active, :mfd)',
      {'name': '[DEV-TEST] $key $stamp', 'active': active, 'mfd': mfd},
    )).lastInsertId;
    return credGroupIds[key] = id;
  }

  Future<int> insertLanguage(String key, {required bool active, bool mfd = false}) async {
    final id = (await db.execute(
      'INSERT INTO tblLanguage (languageName, languageCode, languageActive, languageMFD) VALUES (:name, :code, :active, :mfd)',
      {'name': '[DEV-TEST] $key $stamp', 'code': languageCodes[key] = languageCode(), 'active': active, 'mfd': mfd},
    )).lastInsertId;
    return languageIds[key] = id;
  }

  Future<int> insertUser(String code) async => (await db.execute(
    'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
    "VALUES ('[DEV-TEST]', 'Assign', :code, :qr, 1, 0)",
    {'code': code, 'qr': 'DEV-TEST-$code'},
  )).lastInsertId;

  Future<int> memberships(int companyId) async => (await db.query(
    'SELECT COUNT(*) AS n FROM tblUserCompany WHERE userID = :u AND companyID = :c',
    {'u': userId, 'c': companyId},
  )).single.readInt('n');

  setUpAll(() async {
    db = TestDatabase.connect(maxConnections: 4);
    await insertCompany('home', active: true);
    await insertCompany('other', active: true);
    await insertCompany('inactive', active: false);
    await insertCompany('deleted', active: true, mfd: true);
    await insertGroup('active', active: true);
    await insertGroup('inactive', active: false);
    await insertGroup('deleted', active: true, mfd: true);
    await insertCredGroup('active', active: true);
    await insertCredGroup('inactive', active: false);
    await insertCredGroup('deleted', active: true, mfd: true);
    await insertCredGroup('foreign', active: true);
    await insertLanguage('one', active: true);
    await insertLanguage('two', active: true);
    await insertLanguage('off', active: false);
    userId = await insertUser('DTA$stamp');
    actorId = await insertUser('DTH$stamp');
    await db.execute(
      'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
      {'u': userId, 'c': companyIds['home']},
    );
  });

  tearDownAll(() async {
    final users = [userId, actorId, ...extraUserIds];
    // Every user's events first: a fixture user may be another one's actor.
    for (final id in users) {
      final logs = await db.query('SELECT eventLogID FROM tblEventLog WHERE userIDTarget = :id', {'id': id});
      for (final log in logs) {
        await db.execute('DELETE FROM tblEventLogEventType WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
        await db.execute('DELETE FROM tblEventLog WHERE eventLogID = :l', {'l': log.readInt('eventLogID')});
      }
    }
    for (final id in users) {
      await db.execute('DELETE FROM tblUserCompany WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUserGroup WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUserCredGroup WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUserLanguage WHERE userID = :id', {'id': id});
      await db.execute('DELETE FROM tblUser WHERE userID = :id', {'id': id});
    }
    for (final id in eventTypeIds) {
      await db.execute('DELETE FROM tblEventType WHERE eventTypeID = :id', {'id': id});
    }
    for (final id in languageIds.values) {
      await db.execute('DELETE FROM tblLanguage WHERE languageID = :id', {'id': id});
    }
    for (final id in credGroupIds.values) {
      await db.execute('DELETE FROM tblCredGroup WHERE credGroupID = :id', {'id': id});
    }
    for (final id in groupIds.values) {
      await db.execute('DELETE FROM tblGroup WHERE groupID = :id', {'id': id});
    }
    for (final id in companyIds.values) {
      await db.execute('DELETE FROM tblCompany WHERE companyID = :id', {'id': id});
    }
    await db.close();
  });

  test('options: active companies and memberships; inactive and MFD ones are not offered', () async {
    final options = {for (final o in await repo.companyOptions(db, userId)) o.id: o};

    expect(options[companyIds['home']]!.isAssigned, isTrue);
    expect(options[companyIds['other']]!.isAssigned, isFalse);
    expect(options.containsKey(companyIds['inactive']), isFalse);
    expect(options.containsKey(companyIds['deleted']), isFalse);
  });

  test('adding is idempotent: the pair is created once, never duplicated', () async {
    final other = companyIds['other']!;

    final first = await db.transaction((tx) => repo.addCompany(tx, userId, other));
    final second = await db.transaction((tx) => repo.addCompany(tx, userId, other));

    expect(first, isNotNull);
    expect(second, isNull);
    expect(await memberships(other), 1);
    await db.execute('DELETE FROM tblUserCompany WHERE userID = :u AND companyID = :c', {'u': userId, 'c': other});
  });

  test('two concurrent adds of the same company create one membership', () async {
    final other = companyIds['other']!;

    final results = await Future.wait([
      db.transaction((tx) => repo.addCompany(tx, userId, other)),
      db.transaction((tx) => repo.addCompany(tx, userId, other)),
    ]);

    expect(results.whereType<int>(), hasLength(1));
    expect(await memberships(other), 1);
    await db.execute('DELETE FROM tblUserCompany WHERE userID = :u AND companyID = :c', {'u': userId, 'c': other});
  });

  Future<List<String>> eventTypes(String column, int id) async => [
    for (final row in await db.query(
      'SELECT t.eventTypeName FROM tblEventLog l JOIN tblEventLogEventType et ON et.eventLogID = l.eventLogID '
      'JOIN tblEventType t ON t.eventTypeID = et.eventTypeID '
      'WHERE l.userIDTarget = :u AND l.$column = :id ORDER BY l.eventLogID',
      {'u': userId, 'id': id},
    ))
      row.readString('eventTypeName'),
  ];

  test('companies: a second membership, soft removal (row kept, hidden), reactivation of the same row', () async {
    final home = companyIds['home']!;
    final other = companyIds['other']!;
    Future<List<(int, bool, bool)>> rows() async => [
      for (final row in await db.query(
        'SELECT userCompanyID, userCompanyActive, userCompanyMFD FROM tblUserCompany WHERE userID = :u AND companyID = :c',
        {'u': userId, 'c': other},
      ))
        (row.readInt('userCompanyID'), row.readBool('userCompanyActive'), row.readBool('userCompanyMFD')),
    ];

    await service().addCompanies(actorId, home, userId, AddAssignmentsRequest(ids: [other]), mayManage: (_) async {});
    final [(id, active, mfd)] = await rows();
    expect((active, mfd), (true, false));
    expect(await const EmployeeAssignmentRepository().memberCompanyIds(db, userId), containsAll([home, other]));
    expect(await EmployeeRepository(db).findInCompany(db, other, userId), isNotNull, reason: 'visible in PCA');

    final afterRemoval = await service().removeCompany(actorId, home, userId, other, mayManage: (_) async {});
    expect(await rows(), [(id, false, true)], reason: 'Active = 0, MFD = 1; never deleted');
    expect(afterRemoval.options.firstWhere((o) => o.id == other).isAssigned, isFalse);
    expect(await EmployeeRepository(db).findInCompany(db, other, userId), isNull, reason: 'hidden from that company');
    expect(await EmployeeRepository(db).findInCompany(db, home, userId), isNotNull, reason: 'other membership untouched');
    final user = await db.query('SELECT userActive FROM tblUser WHERE userID = :u', {'u': userId});
    expect(user.single.readBool('userActive'), isTrue, reason: 'the account stays active');

    await service().addCompanies(actorId, home, userId, AddAssignmentsRequest(ids: [other]), mayManage: (_) async {});
    expect(await rows(), [(id, true, false)], reason: 'the same row reactivated');
    expect(await eventTypes('userCompanyID', id), [
      'employee.company.assigned',
      'employee.company.removed',
      'employee.company.assigned',
    ]);

    await service().removeCompany(actorId, home, userId, other, mayManage: (_) async {});
    await expectLater(
      service().removeCompany(actorId, home, userId, home, mayManage: (_) async {}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
    expect(await EmployeeRepository(db).findInCompany(db, home, userId), isNotNull, reason: 'one company remains');
  });

  test('two concurrent removals of one membership audit it once', () async {
    final home = companyIds['home']!;
    final other = companyIds['other']!;
    await service().addCompanies(actorId, home, userId, AddAssignmentsRequest(ids: [other]), mayManage: (_) async {});
    final id = (await db.query(
      'SELECT userCompanyID FROM tblUserCompany WHERE userID = :u AND companyID = :c',
      {'u': userId, 'c': other},
    )).single.readInt('userCompanyID');
    final before = (await eventTypes('userCompanyID', id)).length;

    await Future.wait([
      for (var i = 0; i < 2; i++) service().removeCompany(actorId, home, userId, other, mayManage: (_) async {}),
    ]);

    expect((await eventTypes('userCompanyID', id)).length, before + 1);
  });

  test('groups: universal options, idempotent concurrent add, one audit row with groupID and userGroupID', () async {
    final home = companyIds['home']!;
    final active = groupIds['active']!;
    final options = {for (final o in await repo.groupOptions(db, userId)) o.id: o};
    expect(options[active]!.isAssigned, isFalse);
    expect(options.containsKey(groupIds['inactive']), isFalse);
    expect(options.containsKey(groupIds['deleted']), isFalse);
    final companiesBefore = await db.query('SELECT COUNT(*) AS n FROM tblUserCompany WHERE userID = :u', {'u': userId});

    final results = await Future.wait([
      service().addGroups(actorId, home, userId, AddAssignmentsRequest(ids: [active])),
      service().addGroups(actorId, home, userId, AddAssignmentsRequest(ids: [active])),
    ]);

    expect(results.first.options.firstWhere((o) => o.id == active).isAssigned, isTrue);
    final pairs = await db.query(
      'SELECT userGroupID FROM tblUserGroup WHERE userID = :u AND groupID = :g',
      {'u': userId, 'g': active},
    );
    expect(pairs, hasLength(1), reason: 'concurrent adds create one row');
    final logs = await db.query(
      'SELECT userIDInit, groupID, userGroupID FROM tblEventLog WHERE userIDTarget = :u AND groupID IS NOT NULL',
      {'u': userId},
    );
    expect(logs, hasLength(1), reason: 'one change, one audit row');
    expect(logs.single.readInt('userIDInit'), actorId);
    expect(logs.single.readInt('userGroupID'), pairs.single.readInt('userGroupID'));
    final companiesAfter = await db.query('SELECT COUNT(*) AS n FROM tblUserCompany WHERE userID = :u', {'u': userId});
    expect(companiesAfter.single.readInt('n'), companiesBefore.single.readInt('n'), reason: 'a group grants no company');
  });

  test('credential groups: options, member companies, concurrent add once, audited with credGroupID', () async {
    final home = companyIds['home']!;
    final active = credGroupIds['active']!;
    final options = {for (final o in await repo.credentialGroupOptions(db, userId)) o.id: o};
    expect(options[active]!.isAssigned, isFalse);
    expect(options.containsKey(credGroupIds['inactive']), isFalse);
    expect(options.containsKey(credGroupIds['deleted']), isFalse);
    expect(await repo.memberCompanyIds(db, userId), contains(home));

    await db.execute('INSERT INTO tblUserCredGroup (userID, credGroupID) VALUES (:u, :g)', {'u': actorId, 'g': active});
    final asked = <int>{};
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        service().addCredentialGroups(
          actorId,
          home,
          userId,
          AddAssignmentsRequest(ids: [active]),
          mayManage: (c) async => asked.add(c),
        ),
    ]);

    expect(asked, (await repo.memberCompanyIds(db, userId)).toSet());
    expect(results.first.options.firstWhere((o) => o.id == active).isAssigned, isTrue);
    final pairs = await db.query(
      'SELECT userCredGroupID FROM tblUserCredGroup WHERE userID = :u AND credGroupID = :g',
      {'u': userId, 'g': active},
    );
    expect(pairs, hasLength(1));
    final logs = await db.query(
      'SELECT userIDInit, userCredGroupID FROM tblEventLog WHERE userIDTarget = :u AND credGroupID = :g',
      {'u': userId, 'g': active},
    );
    expect(logs, hasLength(1));
    expect(logs.single.readInt('userIDInit'), actorId);
    expect(logs.single.readInt('userCredGroupID'), pairs.single.readInt('userCredGroupID'));
  });

  test('language: concurrent changes leave one row; each change audited generically', () async {
    final home = companyIds['home']!;
    final one = languageIds['one']!;
    final two = languageIds['two']!;
    final options = {for (final o in await const UserLanguageRepository().options(db, userId)) o.id: o};
    expect(options.containsKey(languageIds['off']), isFalse);
    expect(options[one]!.code, languageCodes['one']);

    await Future.wait([
      service().setLanguage(actorId, home, userId, SetLanguageRequest(languageId: one)),
      service().setLanguage(actorId, home, userId, SetLanguageRequest(languageId: two)),
    ]);

    final rows = await db.query('SELECT languageID FROM tblUserLanguage WHERE userID = :u', {'u': userId});
    expect(rows, hasLength(1), reason: 'the user row lock serializes the two changes');
    final logs = await db.query(
      'SELECT l.userIDInit, t.eventTypeName FROM tblEventLog l '
      'LEFT JOIN tblEventLogEventType et ON et.eventLogID = l.eventLogID '
      'LEFT JOIN tblEventType t ON t.eventTypeID = et.eventTypeID '
      'WHERE l.userIDTarget = :u AND l.groupID IS NULL AND l.companyID IS NULL AND l.credGroupID IS NULL',
      {'u': userId},
    );
    expect(logs, hasLength(2), reason: 'first sets, second replaces: two changes');
    expect(logs.map((r) => r.readInt('userIDInit')).toSet(), {actorId});

    await service().setLanguage(actorId, home, userId, SetLanguageRequest(languageId: rows.single.readInt('languageID')));
    final after = await db.query(
      'SELECT COUNT(*) AS n FROM tblEventLog WHERE userIDTarget = :u AND groupID IS NULL AND companyID IS NULL AND credGroupID IS NULL',
      {'u': userId},
    );
    expect(after.single.readInt('n'), 2, reason: 'choosing the current language is not a change');
  });

  test('credential groups: a group the actor does not hold is refused, nothing written', () async {
    final foreign = credGroupIds['foreign']!;

    final refused = service()
        .addCredentialGroups(actorId, companyIds['home']!, userId, AddAssignmentsRequest(ids: [foreign]), mayManage: (_) async {});

    await expectLater(refused, throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    expect(
      await db.query('SELECT 1 FROM tblUserCredGroup WHERE userID = :u AND credGroupID = :g', {'u': userId, 'g': foreign}),
      isEmpty,
    );
    final options = await service().credentialGroups(actorId, companyIds['home']!, userId);
    expect(options.options.firstWhere((o) => o.id == foreign).isAssignable, isFalse);
  });

  test('groups: soft removal keeps the row, hides it; reactivation reuses it', () async {
    final home = companyIds['home']!;
    final group = groupIds['active']!;
    await service().addGroups(actorId, home, userId, AddAssignmentsRequest(ids: [group]));
    final id = (await db.query(
      'SELECT userGroupID FROM tblUserGroup WHERE userID = :u AND groupID = :g',
      {'u': userId, 'g': group},
    )).single.readInt('userGroupID');

    final removed = await service().removeGroup(actorId, home, userId, group);

    final row = (await db.query(
      'SELECT userGroupActive, userGroupMFD FROM tblUserGroup WHERE userGroupID = :id',
      {'id': id},
    )).single;
    expect((row.readBool('userGroupActive'), row.readBool('userGroupMFD')), (false, true));
    expect(removed.options.firstWhere((o) => o.id == group).isAssigned, isFalse);
    expect((await EmployeeRepository(db).findDetails(home, userId))!.groups, isNot(contains('[DEV-TEST] active $stamp')));

    await service().addGroups(actorId, home, userId, AddAssignmentsRequest(ids: [group]));
    expect(
      (await db.query('SELECT COUNT(*) AS n FROM tblUserGroup WHERE userID = :u AND groupID = :g', {'u': userId, 'g': group}))
          .single
          .readInt('n'),
      1,
    );
    expect((await eventTypes('userGroupID', id)).skip(1), ['employee.group.removed', 'employee.group.assigned']);
  });

  // ── Removed links (Active = 0, MFD = 1) never count ────────────────────

  /// A fresh `[DEV-TEST]` user, member of the home company.
  Future<int> memberOfHome(String code) async {
    final id = await insertUser('$code$stamp');
    extraUserIds.add(id);
    await db.execute(
      'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:u, :c, 1, 0)',
      {'u': id, 'c': companyIds['home']},
    );
    return id;
  }

  Future<int> linkCredentialGroup(int user, int group, {required bool removed}) async => (await db.execute(
    'INSERT INTO tblUserCredGroup (userID, credGroupID, userCredGroupActive, userCredGroupMFD) VALUES (:u, :g, :a, :m)',
    {'u': user, 'g': group, 'a': !removed, 'm': removed},
  )).lastInsertId;

  test('credential groups: a removed link is not held or shown; adding reactivates that row, audited', () async {
    final group = credGroupIds['active']!;
    final target = await memberOfHome('DRT');
    final actor = await memberOfHome('DRA');
    await linkCredentialGroup(actor, group, removed: false);
    final removedId = await linkCredentialGroup(target, group, removed: true);

    expect(await repo.heldCredentialGroupIds(db, target), isNot(contains(group)));
    final before = {for (final o in await repo.credentialGroupOptions(db, target)) o.id: o};
    expect(before[group]!.isAssigned, isFalse);

    final result = await service().addCredentialGroups(
      actor,
      companyIds['home']!,
      target,
      AddAssignmentsRequest(ids: [group]),
      mayManage: (_) async {},
    );

    expect(result.options.firstWhere((o) => o.id == group).isAssigned, isTrue);
    final rows = await db.query(
      'SELECT userCredGroupID, userCredGroupActive, userCredGroupMFD FROM tblUserCredGroup WHERE userID = :u AND credGroupID = :g',
      {'u': target, 'g': group},
    );
    expect(
      [for (final r in rows) (r.readInt('userCredGroupID'), r.readBool('userCredGroupActive'), r.readBool('userCredGroupMFD'))],
      [(removedId, true, false)],
      reason: 'the removed row is reactivated, never duplicated',
    );
    expect(await repo.heldCredentialGroupIds(db, target), contains(group));
    final logs = await db.query(
      'SELECT userCredGroupID FROM tblEventLog WHERE userIDTarget = :u AND credGroupID = :g',
      {'u': target, 'g': group},
    );
    expect([for (final l in logs) l.readInt('userCredGroupID')], [removedId]);
  });

  test('credential groups: an actor whose own link is removed cannot grant that group', () async {
    final group = credGroupIds['active']!;
    final target = await memberOfHome('DRU');
    final actor = await memberOfHome('DRB');
    await linkCredentialGroup(actor, group, removed: true);

    final refused = service().addCredentialGroups(
      actor,
      companyIds['home']!,
      target,
      AddAssignmentsRequest(ids: [group]),
      mayManage: (_) async {},
    );

    await expectLater(refused, throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    expect(
      await db.query('SELECT 1 FROM tblUserCredGroup WHERE userID = :u AND credGroupID = :g', {'u': target, 'g': group}),
      isEmpty,
    );
  });

  test('language: a removed row is ignored; choosing its language reactivates it and removes the current one', () async {
    final one = languageIds['one']!;
    final two = languageIds['two']!;
    final target = await memberOfHome('DRL');
    Future<int> link(int language, {required bool removed}) async => (await db.execute(
      'INSERT INTO tblUserLanguage (userID, languageID, userLanguageActive, userLanguageMFD) VALUES (:u, :l, :a, :m)',
      {'u': target, 'l': language, 'a': !removed, 'm': removed},
    )).lastInsertId;
    final currentId = await link(one, removed: false);
    final removedId = await link(two, removed: true);

    expect(await const UserLanguageRepository().assigned(db, target), [(userLanguageId: currentId, languageId: one)]);
    final options = {for (final o in await const UserLanguageRepository().options(db, target)) o.id: o};
    expect((options[one]!.isAssigned, options[two]!.isAssigned), (true, false));
    expect(await LanguageRepository(db).activeLanguageCodesForUser(target), [languageCodes['one']]);

    await service().setLanguage(actorId, companyIds['home']!, target, SetLanguageRequest(languageId: two));

    final rows = await db.query(
      'SELECT userLanguageID, userLanguageActive, userLanguageMFD FROM tblUserLanguage WHERE userID = :u ORDER BY userLanguageID',
      {'u': target},
    );
    expect(
      [for (final r in rows) (r.readInt('userLanguageID'), r.readBool('userLanguageActive'), r.readBool('userLanguageMFD'))],
      [(currentId, false, true), (removedId, true, false)],
      reason: 'one current row; nothing deleted or duplicated',
    );
    expect(await LanguageRepository(db).activeLanguageCodesForUser(target), [languageCodes['two']]);
  });

  test('account-access events: an event whose type link is removed does not count', () async {
    final target = await memberOfHome('DRE');
    final name = '[DEV-TEST] access $stamp';
    final typeId = (await db.execute('INSERT INTO tblEventType (eventTypeName) VALUES (:n)', {'n': name})).lastInsertId;
    eventTypeIds.add(typeId);
    final logId = (await db.execute(
      'INSERT INTO tblEventLog (eventLogTimestamp, userIDInit, userIDTarget) VALUES (UTC_TIMESTAMP(), :a, :u)',
      {'a': actorId, 'u': target},
    )).lastInsertId;
    await db.execute(
      'INSERT INTO tblEventLogEventType (eventTypeID, eventLogID, eventLogEventTypeActive, eventLogEventTypeMFD) '
      'VALUES (:t, :l, 0, 1)',
      {'t': typeId, 'l': logId},
    );
    const onboarding = OnboardingRepository();

    expect(await onboarding.latestAccessEvent(db, target, [name]), isNull);

    await db.execute(
      'UPDATE tblEventLogEventType SET eventLogEventTypeActive = 1, eventLogEventTypeMFD = 0 WHERE eventLogID = :l',
      {'l': logId},
    );
    expect(await onboarding.latestAccessEvent(db, target, [name]), name);
  });
}

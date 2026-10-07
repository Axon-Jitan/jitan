@Tags(['integration'])
library;

import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/languages/language_repository.dart';
import 'package:jitan_api/src/languages/translation_repository.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';

/// Real SQL for languages/translations against `[DEV-TEST]` fixtures,
/// removed in tearDown.
void main() {
  final skip = TestDatabase.skipReason;
  if (skip != null) {
    test('integration tests', () {}, skip: skip);
    return;
  }

  late Database db;
  final stamp = DateTime.now().microsecondsSinceEpoch % 1000000;
  final activeCode = 'dt$stamp';
  final inactiveCode = 'dx$stamp';
  final languageIds = <int>[];
  final userIds = <int>[];

  Future<int> insertLanguage(String code, {bool active = true}) async {
    await db.query(
      'INSERT INTO tblLanguage (languageName, languageCode, languageActive, languageMFD) '
      'VALUES (:name, :code, :active, 0)',
      {'name': '[DEV-TEST] $code', 'code': code, 'active': active},
    );
    final id = (await db.query('SELECT languageID FROM tblLanguage WHERE languageCode = :code', {'code': code}))
        .single
        .readInt('languageID');
    languageIds.add(id);
    return id;
  }

  setUpAll(() => db = TestDatabase.connect());

  tearDownAll(() async {
    for (final id in userIds) {
      await db.query('DELETE FROM tblUserLanguage WHERE userID = :id', {'id': id});
      await db.query('DELETE FROM tblUser WHERE userID = :id', {'id': id});
    }
    for (final id in languageIds) {
      await db.query('DELETE FROM tblTranslation WHERE languageID = :id', {'id': id});
      await db.query('DELETE FROM tblUserLanguage WHERE languageID = :id', {'id': id});
      await db.query('DELETE FROM tblLanguage WHERE languageID = :id', {'id': id});
    }
    await db.close();
  });

  test('finds active languages and ignores inactive ones', () async {
    await insertLanguage(activeCode);
    await insertLanguage(inactiveCode, active: false);
    final repository = LanguageRepository(db);

    expect((await repository.findActiveByCode(activeCode))?.code, activeCode);
    expect(await repository.findActiveByCode(inactiveCode), isNull);
    final listed = (await repository.listActiveLanguages()).map((l) => l.code);
    expect(listed, contains(activeCode));
    expect(listed, isNot(contains(inactiveCode)));
  });

  test('loads a translation bundle; the lowest translationID wins on duplicates', () async {
    final id = languageIds.isNotEmpty ? languageIds.first : await insertLanguage(activeCode);
    for (final (key, text) in [('test.a', 'First'), ('test.b', "O'Brien \\ text"), ('test.a', 'Second')]) {
      await db.query(
        'INSERT INTO tblTranslation (languageID, translationUIName, translationUIText) VALUES (:id, :key, :text)',
        {'id': id, 'key': key, 'text': text},
      );
    }

    final texts = await TranslationRepository(db).textsForLanguage(id);

    expect(texts, {'test.a': 'First', 'test.b': "O'Brien \\ text"});
  });

  test("resolves a user's active languages only", () async {
    final active = languageIds.first;
    final inactive = languageIds.last;
    final code = 'DT-LANG-$stamp';
    await db.query(
      'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userActive, userMFD) '
      "VALUES ('[DEV-TEST]', 'Language', :code, :qr, 1, 0)",
      {'code': code, 'qr': 'DEV-TEST-$code'},
    );
    final userId =
        (await db.query('SELECT userID FROM tblUser WHERE userCode = :code', {'code': code})).single.readInt('userID');
    userIds.add(userId);
    for (final languageId in [active, inactive]) {
      await db.query(
        'INSERT INTO tblUserLanguage (userID, languageID) VALUES (:user, :language)',
        {'user': userId, 'language': languageId},
      );
    }

    expect(await LanguageRepository(db).activeLanguageCodesForUser(userId), [activeCode]);
  });
}

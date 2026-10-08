// DEVELOPMENT ONLY: fills a dev/test database with clearly marked fake data.
//
//   dart run tool/dev_seed.dart                    insert (idempotent)
//   dart run tool/dev_seed.dart --pseudo-language  also add a fake database language
//   dart run tool/dev_seed.dart --remove           delete everything this tool created
//
// Reads the same JITAN_* variables / .env as the server and refuses to run
// unless JITAN_ENV is development or test. Every record is prefixed "[DEV]"
// (companies, user first names, language name) or "DEV-" (user codes), and
// nothing in production code refers to these records.
//
// English is NOT seeded: it is built into the apps (builtInEnglish in
// jitan_core) and never read from the database. --pseudo-language creates
// "[DEV] Pseudo" (code `xx`) whose texts are the built-in English wrapped in
// ⟦…⟧, and assigns it to the DEV-ADMIN user, so the database translation path
// (tblLanguage → tblTranslation → tblUserLanguage → API → app) can be seen
// working: wrapped text came from the database, plain text is the fallback.
//
// Groups: "[DEV] White collar" and "[DEV] Blue collar"; seeded employees
// alternate between them, and one per company has both (to show the
// several-groups case).
//
// Not seeded: tblEventLog (event types are pending CLARIFY-11), so the
// company list's "Last updated" stays empty for seeded companies.

import 'dart:io';

import 'package:jitan_api/src/config/app_config.dart';
import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/env_file.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_core/jitan_core.dart';

const _companyPrefix = '[DEV] ';
const _userCodePrefix = 'DEV-';
const _pseudoLanguageCode = 'xx';
const _pseudoLanguageName = '[DEV] Pseudo';

/// Companies (name, active) and members per company.
const _companies = [
  ('Almeco', true, 6),
  ('PCA', true, 4),
  ('Akwa Plus', true, 3),
  ('Proceq', false, 2),
];

Future<void> main(List<String> args) async {
  final remove = args.contains('--remove');
  final pseudoLanguage = args.contains('--pseudo-language');

  final AppConfig config;
  try {
    final envFile = File('.env');
    config = AppConfig.fromEnvironment({
      if (envFile.existsSync()) ...parseEnvFile(envFile.readAsLinesSync()),
      ...Platform.environment,
    });
  } on ConfigException catch (e) {
    stderr.writeln('Refusing to run: ${e.message}');
    exitCode = 78;
    return;
  }
  if (!config.environment.allowsDevelopmentMechanisms) {
    stderr.writeln('Refusing to run: JITAN_ENV must be development or test (is ${config.environment.name}).');
    exitCode = 78;
    return;
  }

  stdout.writeln('Database: ${config.database}');
  final db = Database.connect(config.database, maxConnections: 1);
  try {
    if (remove) {
      await _remove(db);
    } else {
      await _seed(db, pseudoLanguage: pseudoLanguage);
    }
  } finally {
    await db.close();
  }
}

Future<void> _seed(Database db, {required bool pseudoLanguage}) async {
  final devAdminId = await _ensureUser(db, code: '${_userCodePrefix}ADMIN', first: '[DEV]', last: 'Developer');
  stdout.writeln('Development user: tblUser.userID=$devAdminId  ->  set JITAN_DEV_USER_ID=$devAdminId');

  final whiteCollar = await _ensureGroup(db, '${_companyPrefix}White collar');
  final blueCollar = await _ensureGroup(db, '${_companyPrefix}Blue collar');

  for (final (name, active, members) in _companies) {
    final companyId = await _ensureCompany(db, '$_companyPrefix$name', active: active);
    await _ensureMembership(db, devAdminId, companyId);
    for (var i = 1; i <= members; i++) {
      final code = '$_userCodePrefix${name.replaceAll(' ', '').toUpperCase()}-$i';
      final userId = await _ensureUser(db, code: code, first: '[DEV]', last: '$name employee $i');
      await _ensureMembership(db, userId, companyId);
      await _ensureUserGroup(db, userId, i.isOdd ? whiteCollar : blueCollar);
      if (i == members) await _ensureUserGroup(db, userId, i.isOdd ? blueCollar : whiteCollar);
    }
    stdout.writeln('Company "$_companyPrefix$name" (id $companyId, ${active ? 'active' : 'inactive'}): $members employees');
  }
  if (pseudoLanguage) await _ensurePseudoLanguage(db, devAdminId);
  stdout.writeln('Done.');
}

/// "[DEV] Pseudo" (`xx`): built-in English wrapped in ⟦…⟧, assigned to the
/// dev admin. One key ('common.retry') is deliberately left out so the
/// English fallback is visible too.
Future<void> _ensurePseudoLanguage(Database db, int devAdminId) async {
  Future<int?> find() async {
    final rows = await db.query(
      'SELECT languageID FROM tblLanguage WHERE languageCode = :code',
      {'code': _pseudoLanguageCode},
    );
    return rows.isEmpty ? null : rows.single.readInt('languageID');
  }

  var languageId = await find();
  if (languageId == null) {
    await db.query(
      'INSERT INTO tblLanguage (languageName, languageCode, languageActive, languageMFD) VALUES (:name, :code, 1, 0)',
      {'name': _pseudoLanguageName, 'code': _pseudoLanguageCode},
    );
    languageId = await find() ?? (throw StateError('Inserted the pseudo language but cannot read it back.'));
  }

  final existing = {
    for (final row in await db.query(
      'SELECT translationUIName FROM tblTranslation WHERE languageID = :id',
      {'id': languageId},
    ))
      row.readString('translationUIName'),
  };
  var added = 0;
  for (final MapEntry(:key, :value) in builtInEnglish.entries) {
    if (key == 'common.retry' || existing.contains(key)) continue;
    await db.query(
      'INSERT INTO tblTranslation (languageID, translationUIName, translationUIText) VALUES (:id, :key, :text)',
      {'id': languageId, 'key': key, 'text': '⟦$value⟧'},
    );
    added++;
  }

  final assigned = await db.query('SELECT languageID FROM tblUserLanguage WHERE userID = :user', {'user': devAdminId});
  if (assigned.isEmpty) {
    await db.query(
      'INSERT INTO tblUserLanguage (userID, languageID) VALUES (:user, :language)',
      {'user': devAdminId, 'language': languageId},
    );
  } else if (assigned.every((r) => r.readInt('languageID') != languageId)) {
    stdout.writeln('DEV-ADMIN already has another language; pseudo language NOT assigned.');
  }
  stdout.writeln('Pseudo language "$_pseudoLanguageName" ($_pseudoLanguageCode, id $languageId): $added texts added.');
}

Future<void> _remove(Database db) async {
  final users = await db.query(
    "SELECT userID FROM tblUser WHERE userCode LIKE CONCAT(:prefix, '%')",
    {'prefix': _userCodePrefix},
  );
  final companies = await db.query(
    "SELECT companyID FROM tblCompany WHERE companyName LIKE CONCAT(:prefix, '%')",
    {'prefix': _companyPrefix},
  );
  final groups = await db.query(
    "SELECT groupID FROM tblGroup WHERE groupName LIKE CONCAT(:prefix, '%')",
    {'prefix': _companyPrefix},
  );
  final languages = await db.query(
    'SELECT languageID FROM tblLanguage WHERE languageCode = :code AND languageName = :name',
    {'code': _pseudoLanguageCode, 'name': _pseudoLanguageName},
  );
  for (final row in users) {
    final id = row.readInt('userID');
    await db.query('DELETE FROM tblUserLanguage WHERE userID = :id', {'id': id});
    await db.query('DELETE FROM tblUserGroup WHERE userID = :id', {'id': id});
    await db.query('DELETE FROM tblUserCompany WHERE userID = :id', {'id': id});
    await db.query('DELETE FROM tblUser WHERE userID = :id', {'id': id});
  }
  for (final row in companies) {
    final id = row.readInt('companyID');
    await db.query('DELETE FROM tblUserCompany WHERE companyID = :id', {'id': id});
    await db.query('DELETE FROM tblCompany WHERE companyID = :id', {'id': id});
  }
  for (final row in groups) {
    final id = row.readInt('groupID');
    await db.query('DELETE FROM tblUserGroup WHERE groupID = :id', {'id': id});
    await db.query('DELETE FROM tblGroup WHERE groupID = :id', {'id': id});
  }
  for (final row in languages) {
    final id = row.readInt('languageID');
    await db.query('DELETE FROM tblUserLanguage WHERE languageID = :id', {'id': id});
    await db.query('DELETE FROM tblTranslation WHERE languageID = :id', {'id': id});
    await db.query('DELETE FROM tblLanguage WHERE languageID = :id', {'id': id});
  }
  stdout.writeln('Removed ${users.length} dev users, ${companies.length} dev companies, '
      '${groups.length} dev groups and ${languages.length} dev language(s).');
}

Future<int> _ensureCompany(Database db, String name, {required bool active}) async {
  Future<int?> find() async {
    final rows = await db.query('SELECT companyID FROM tblCompany WHERE companyName = :name', {'name': name});
    return rows.isEmpty ? null : rows.first.readInt('companyID');
  }

  final existing = await find();
  if (existing != null) return existing;
  await db.query(
    'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:name, :active, 0)',
    {'name': name, 'active': active},
  );
  return await find() ?? (throw StateError('Inserted company "$name" but cannot read it back.'));
}

Future<int> _ensureUser(Database db, {required String code, required String first, required String last}) async {
  Future<int?> find() async {
    final rows = await db.query('SELECT userID FROM tblUser WHERE userCode = :code', {'code': code});
    return rows.isEmpty ? null : rows.first.readInt('userID');
  }

  final existing = await find();
  if (existing != null) return existing;
  await db.query(
    'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, userKioskMode, userActive, userMFD) '
    'VALUES (:first, :last, :code, :qr, 0, 1, 0)',
    {'first': first, 'last': last, 'code': code, 'qr': 'DEV-QR-$code'},
  );
  return await find() ?? (throw StateError('Inserted user "$code" but cannot read it back.'));
}

Future<int> _ensureGroup(Database db, String name) async {
  Future<int?> find() async {
    final rows = await db.query('SELECT groupID FROM tblGroup WHERE groupName = :name', {'name': name});
    return rows.isEmpty ? null : rows.first.readInt('groupID');
  }

  final existing = await find();
  if (existing != null) return existing;
  await db.query('INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:name, 1, 0)', {'name': name});
  return await find() ?? (throw StateError('Inserted group "$name" but cannot read it back.'));
}

Future<void> _ensureUserGroup(Database db, int userId, int groupId) async {
  final existing = await db.query(
    'SELECT 1 AS found FROM tblUserGroup WHERE userID = :user AND groupID = :group',
    {'user': userId, 'group': groupId},
  );
  if (existing.isNotEmpty) return;
  await db.query(
    'INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES (:user, :group, 1, 0)',
    {'user': userId, 'group': groupId},
  );
}

Future<void> _ensureMembership(Database db, int userId, int companyId) async {
  final existing = await db.query(
    'SELECT 1 AS found FROM tblUserCompany WHERE userID = :user AND companyID = :company',
    {'user': userId, 'company': companyId},
  );
  if (existing.isNotEmpty) return;
  await db.query(
    'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES (:user, :company, 1, 0)',
    {'user': userId, 'company': companyId},
  );
}

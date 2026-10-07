// DEVELOPMENT ONLY: fills a dev/test database with clearly marked fake data.
//
//   dart run tool/dev_seed.dart           insert (idempotent)
//   dart run tool/dev_seed.dart --remove  delete everything this tool created
//
// Reads the same JITAN_* variables / .env as the server and refuses to run
// unless JITAN_ENV is development or test. Every record is prefixed "[DEV]"
// (companies, user first names) or "DEV-" (user codes), and nothing in
// production code refers to these records.
//
// Also ensures an English tblLanguage row ('en') and inserts the English
// UI texts from tool/dev_translations_en.dart that are missing. These are
// real content, not fake data, so --remove leaves them in place.
//
// Not seeded: tblEventLog (event types are pending CLARIFY-11), so the
// company list's "Last updated" stays empty for seeded companies.

import 'dart:io';

import 'package:jitan_api/src/config/app_config.dart';
import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/env_file.dart';
import 'package:jitan_api/src/database/database.dart';

import 'dev_translations_en.dart';

const _companyPrefix = '[DEV] ';
const _userCodePrefix = 'DEV-';

/// Companies (name, active) and members per company.
const _companies = [
  ('Almeco', true, 6),
  ('PCA', true, 4),
  ('Akwa Plus', true, 3),
  ('Proceq', false, 2),
];

Future<void> main(List<String> args) async {
  final remove = args.contains('--remove');

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
      await _seed(db);
    }
  } finally {
    await db.close();
  }
}

Future<void> _seed(Database db) async {
  final devAdminId = await _ensureUser(db, code: '${_userCodePrefix}ADMIN', first: '[DEV]', last: 'Developer');
  stdout.writeln('Development user: tblUser.userID=$devAdminId  ->  set JITAN_DEV_USER_ID=$devAdminId');

  for (final (name, active, members) in _companies) {
    final companyId = await _ensureCompany(db, '$_companyPrefix$name', active: active);
    await _ensureMembership(db, devAdminId, companyId);
    for (var i = 1; i <= members; i++) {
      final code = '$_userCodePrefix${name.replaceAll(' ', '').toUpperCase()}-$i';
      final userId = await _ensureUser(db, code: code, first: '[DEV]', last: '$name employee $i');
      await _ensureMembership(db, userId, companyId);
    }
    stdout.writeln('Company "$_companyPrefix$name" (id $companyId, ${active ? 'active' : 'inactive'}): $members employees');
  }
  await _ensureEnglishTranslations(db);
  stdout.writeln('Done.');
}

Future<void> _ensureEnglishTranslations(Database db) async {
  var rows = await db.query("SELECT languageID FROM tblLanguage WHERE languageCode = 'en'");
  if (rows.isEmpty) {
    await db.query(
      "INSERT INTO tblLanguage (languageName, languageCode, languageActive, languageMFD) VALUES ('English', 'en', 1, 0)",
    );
    rows = await db.query("SELECT languageID FROM tblLanguage WHERE languageCode = 'en'");
    stdout.writeln('Created tblLanguage row for English (en).');
  }
  final languageId = rows.single.readInt('languageID');

  final existing = {
    for (final row in await db.query(
      'SELECT translationUIName FROM tblTranslation WHERE languageID = :id',
      {'id': languageId},
    ))
      row.readString('translationUIName'),
  };
  var added = 0;
  for (final MapEntry(:key, :value) in devEnglishTranslations.entries) {
    if (existing.contains(key)) continue;
    await db.query(
      'INSERT INTO tblTranslation (languageID, translationUIName, translationUIText) VALUES (:id, :key, :text)',
      {'id': languageId, 'key': key, 'text': value},
    );
    added++;
  }
  stdout.writeln('English translations: $added added, ${existing.length} already present (existing rows untouched).');
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
  for (final row in users) {
    final id = row.readInt('userID');
    await db.query('DELETE FROM tblUserCompany WHERE userID = :id', {'id': id});
    await db.query('DELETE FROM tblUser WHERE userID = :id', {'id': id});
  }
  for (final row in companies) {
    final id = row.readInt('companyID');
    await db.query('DELETE FROM tblUserCompany WHERE companyID = :id', {'id': id});
    await db.query('DELETE FROM tblCompany WHERE companyID = :id', {'id': id});
  }
  stdout.writeln('Removed ${users.length} dev users and ${companies.length} dev companies.');
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

Future<void> _ensureMembership(Database db, int userId, int companyId) async {
  final existing = await db.query(
    'SELECT 1 AS found FROM tblUserCompany WHERE userID = :user AND companyID = :company',
    {'user': userId, 'company': companyId},
  );
  if (existing.isNotEmpty) return;
  await db.query(
    'INSERT INTO tblUserCompany (userID, companyID) VALUES (:user, :company)',
    {'user': userId, 'company': companyId},
  );
}

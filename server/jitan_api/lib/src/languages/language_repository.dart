import 'package:jitan_models/jitan_models.dart';

import '../database/database.dart';
import '../database/db_row.dart';

/// Data access for `tblLanguage` and `tblUserLanguage`.
class LanguageRepository {
  const LanguageRepository(this._db);

  final Database _db;

  static const _activeLanguageFilter = 'l.languageActive = 1 AND l.languageMFD = 0';

  /// Languages users can choose: `languageActive = 1`, `languageMFD = 0`.
  Future<List<Language>> listActiveLanguages() async {
    final rows = await _db.query(
      'SELECT l.languageID, l.languageCode, l.languageName FROM tblLanguage l '
      'WHERE $_activeLanguageFilter ORDER BY l.languageName, l.languageID',
    );
    return rows.map(_toLanguage).toList();
  }

  /// The active language with [code], or `null`.
  Future<Language?> findActiveByCode(String code) async {
    final rows = await _db.query(
      'SELECT l.languageID, l.languageCode, l.languageName FROM tblLanguage l '
      'WHERE l.languageCode = :code AND $_activeLanguageFilter',
      {'code': code},
    );
    return rows.isEmpty ? null : _toLanguage(rows.single);
  }

  /// Codes of the **active** languages assigned to [userId] in
  /// `tblUserLanguage`. A disabled or deleted language no longer applies.
  Future<List<String>> activeLanguageCodesForUser(int userId) async {
    final rows = await _db.query(
      'SELECT l.languageCode FROM tblUserLanguage ul '
      'JOIN tblLanguage l ON l.languageID = ul.languageID '
      'WHERE ul.userID = :userId AND $_activeLanguageFilter '
      'ORDER BY l.languageCode',
      {'userId': userId},
    );
    return [for (final row in rows) row.readString('languageCode')];
  }

  static Language _toLanguage(DbRow row) => Language(
        id: row.readInt('languageID'),
        code: row.readString('languageCode'),
        name: row.readString('languageName'),
      );
}

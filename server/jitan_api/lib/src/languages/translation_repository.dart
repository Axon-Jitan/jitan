import 'package:logging/logging.dart';

import '../database/database.dart';

final _log = Logger('languages.translations');

/// Data access for `tblTranslation`.
class TranslationRepository {
  const TranslationRepository(this._db);

  final Database _db;

  /// Every translation of [languageId] as `translationUIName → translationUIText`.
  ///
  /// Data problems are logged, not hidden (CLARIFY-08):
  /// - a key stored twice for one language keeps the row with the lowest
  ///   `translationID` and logs a warning naming the key;
  /// - a NULL key or text is skipped and logged.
  Future<Map<String, String>> textsForLanguage(int languageId) async {
    final rows = await _db.query(
      'SELECT translationID, translationUIName, translationUIText FROM tblTranslation '
      'WHERE languageID = :languageId ORDER BY translationID',
      {'languageId': languageId},
    );

    final texts = <String, String>{};
    for (final row in rows) {
      final id = row.readInt('translationID');
      final key = row.readOptionalString('translationUIName');
      final text = row.readOptionalString('translationUIText');
      if (key == null || text == null) {
        _log.warning('tblTranslation $id (languageID $languageId) has a NULL key or text; skipped.');
        continue;
      }
      if (texts.containsKey(key)) {
        _log.warning('Duplicate key "$key" for languageID $languageId: translationID $id ignored, '
            'the lower translationID is used (CLARIFY-08).');
        continue;
      }
      texts[key] = text;
    }
    return texts;
  }
}

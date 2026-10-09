import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';
import '../employees/membership_filters.dart';

/// One `tblUserLanguage` row: which language a user has.
typedef UserLanguageRow = ({int userLanguageId, int languageId});

/// Data access for a user's preferred language (`tblUserLanguage`). One
/// current language per user (product decision 2026-10-08, CLARIFY-07):
/// a change updates that row; nothing is deleted. Only current rows
/// (`Active = 1 AND MFD = 0`) count; a removed row stays hidden.
class UserLanguageRepository {
  const UserLanguageRepository();

  /// The user's current `tblUserLanguage` rows. More than one is a data
  /// error the caller reports; it never picks one.
  ///
  /// With [forUpdate] (inside a transaction) this is a locking read: it sees
  /// the latest committed rows, not the transaction's earlier snapshot.
  Future<List<UserLanguageRow>> assigned(SqlExecutor executor, int userId, {bool forUpdate = false}) async {
    final rows = await executor.query(
      'SELECT ul.userLanguageID, ul.languageID FROM tblUserLanguage ul '
      'WHERE ul.userID = :userId AND ${MembershipFilters.activeLanguage('ul')} ORDER BY ul.userLanguageID'
      '${forUpdate ? ' FOR UPDATE' : ''}',
      {'userId': userId},
    );
    return [
      for (final row in rows) (userLanguageId: row.readInt('userLanguageID'), languageId: row.readInt('languageID')),
    ];
  }

  /// Makes [languageId] the user's language: updates [current] when the
  /// user has one, inserts the first row otherwise.
  ///
  /// A removed row for [languageId] (the unique pair allows only one) is
  /// reactivated instead, and [current] is soft-removed, so there is still
  /// exactly one current row. Callers hold the user's row lock.
  Future<void> save(SqlExecutor tx, int userId, int languageId, {UserLanguageRow? current}) async {
    final removed = await tx.query(
      'SELECT ul.userLanguageID FROM tblUserLanguage ul WHERE ul.userID = :userId AND ul.languageID = :languageId '
      'AND NOT (${MembershipFilters.activeLanguage('ul')})',
      {'userId': userId, 'languageId': languageId},
    );
    if (removed.isNotEmpty) {
      if (current != null) {
        await tx.execute(
          'UPDATE tblUserLanguage SET userLanguageActive = 0, userLanguageMFD = 1 WHERE userLanguageID = :id',
          {'id': current.userLanguageId},
        );
      }
      await tx.execute(
        'UPDATE tblUserLanguage SET userLanguageActive = 1, userLanguageMFD = 0 WHERE userLanguageID = :id',
        {'id': removed.single.readInt('userLanguageID')},
      );
    } else if (current == null) {
      await tx.execute(
        'INSERT INTO tblUserLanguage (userID, languageID, userLanguageActive, userLanguageMFD) '
        'VALUES (:userId, :languageId, 1, 0)',
        {'userId': userId, 'languageId': languageId},
      );
    } else {
      await tx.execute(
        'UPDATE tblUserLanguage SET languageID = :languageId WHERE userLanguageID = :id',
        {'languageId': languageId, 'id': current.userLanguageId},
      );
    }
  }

  /// Whether [languageId] can be chosen: active and not MFD.
  Future<bool> isSelectable(SqlExecutor executor, int languageId) async => (await executor.query(
        'SELECT 1 FROM tblLanguage WHERE languageID = :id AND languageActive = 1 AND languageMFD = 0',
        {'id': languageId},
      ))
          .isNotEmpty;

  /// Every non-MFD language that is active or is [userId]'s, with its code,
  /// ordered by name.
  Future<List<AssignmentOption>> options(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT l.languageID, l.languageName, l.languageCode, l.languageActive, '
      '(ul.userLanguageID IS NOT NULL) AS isAssigned '
      'FROM tblLanguage l '
      'LEFT JOIN tblUserLanguage ul ON ul.languageID = l.languageID AND ul.userID = :userId '
      'AND ${MembershipFilters.activeLanguage('ul')} '
      'WHERE l.languageMFD = 0 AND (l.languageActive = 1 OR ul.userLanguageID IS NOT NULL) '
      'ORDER BY l.languageName, l.languageID',
      {'userId': userId},
    );
    return [
      for (final row in rows)
        AssignmentOption(
          id: row.readInt('languageID'),
          name: row.readOptionalString('languageName') ?? '',
          code: row.readOptionalString('languageCode'),
          isActive: row.readBool('languageActive'),
          isAssigned: row.readBool('isAssigned'),
        ),
    ];
  }
}

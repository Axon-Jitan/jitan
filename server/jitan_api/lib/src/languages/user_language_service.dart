import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../employees/employee_repository.dart';
import '../http/api_exception.dart';
import 'user_language_repository.dart';

/// Changing a user's preferred language: one rule for the employee
/// (`PUT /me/language`) and HR/Admin (Manage assignments → Language).
///
/// A preference update, not a deletion (product decision 2026-10-08): the
/// one `tblUserLanguage` row is updated in place, and each actual change is
/// audited as a generic `employee.language.changed` event. `tblEventLog`
/// has no language column, so the event does not say which language (GAP-12,
/// accepted for V1).
class UserLanguageService {
  UserLanguageService({
    required this._userLanguages,
    required this._employees,
    required this._audit,
    required this._transactions,
  });

  final UserLanguageRepository _userLanguages;
  final EmployeeRepository _employees;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;

  /// Makes [languageId] the language of [userId]. Returns whether anything
  /// changed (choosing the current language is a no-op, not audited).
  ///
  /// The user row is locked first, so concurrent changes for one user run
  /// one after the other; the rows are then read with a locking read (a plain
  /// read would see the snapshot from before the wait) and never end up as
  /// two. [precondition] (e.g. "is still a member of this company") runs
  /// after the lock.
  Future<bool> change({
    required int actorUserId,
    required int userId,
    required int languageId,
    Future<void> Function(SqlExecutor tx)? precondition,
  }) =>
      _transactions.transaction((tx) async {
        if (!await _employees.lockUser(tx, userId)) {
          throw ApiException.notFound('User $userId does not exist.');
        }
        await precondition?.call(tx);
        if (!await _userLanguages.isSelectable(tx, languageId)) {
          throw const ApiException.validation(SetLanguageRequest.fieldLanguageId, 'Choose an active language.');
        }
        final current = await _userLanguages.assigned(tx, userId, forUpdate: true);
        if (current.length > 1) {
          throw ApiException.configurationError(
            'User $userId has ${current.length} languages; expected at most one (CLARIFY-07).',
          );
        }
        if (current.firstOrNull?.languageId == languageId) return false;
        await _userLanguages.save(tx, userId, languageId, current: current.firstOrNull);
        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.languageChanged,
            actorUserId: actorUserId,
            references: {EventLogReference.user: userId},
          ),
        );
        return true;
      });
}

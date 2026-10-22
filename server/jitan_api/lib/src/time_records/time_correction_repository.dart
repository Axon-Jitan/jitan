import '../database/sql_executor.dart';
import 'time_record_repository.dart';

/// Switches `tblTimeReg` rows off for corrections (TIME_ENGINE_ANALYSIS D8,
/// D31): `timeRegActive = 0` with the moment in `timeRegWhenModified`.
/// Nothing is deleted or changed otherwise, except the reason HR gives for a
/// non-work day, kept on its rounded rows.
class TimeCorrectionRepository {
  const TimeCorrectionRepository();

  /// Switches [ids] off at [now]; with [comment], also sets their
  /// `timeRegComment` (only rows without one are given it).
  Future<void> switchOff(SqlExecutor tx, List<int> ids, DateTime now, {String? comment}) async {
    for (final id in ids) {
      await tx.execute(
        'UPDATE tblTimeReg SET timeRegActive = 0, timeRegWhenModified = :now, '
        'timeRegComment = COALESCE(timeRegComment, :comment) WHERE timeRegID = :id AND timeRegActive = 1',
        {'id': id, 'now': TimeRecordRepository.sqlDateTime(now), 'comment': comment},
      );
    }
  }
}

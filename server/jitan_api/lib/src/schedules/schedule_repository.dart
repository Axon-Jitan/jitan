import '../database/sql_executor.dart';
import '../employees/membership_filters.dart';
import 'schedule_names.dart';

/// A `tblDays` row.
typedef DayRow = ({int id, String name});

/// An employee who is in exactly one group: that group's schedules are theirs.
typedef SingleGroupMember = ({int groupId, int userId});

/// A schedule an employee currently has (`tblUserSchedule` → `tblSchedule`),
/// with its type name and day.
typedef UserScheduleRow = ({
  int userId,
  int scheduleId,
  String typeName,
  int dayId,
  int startHour,
  int startMinute,
  int stopHour,
  int stopMinute,
  int marginMinutes,
});

/// A rounding rule linked to a schedule (`tblScheduleRoundingRule` →
/// `tblRoundingRule`).
typedef ScheduleRuleRow = ({int scheduleId, int intervalMinutes, bool roundUp});

/// Data access for schedules: `tblDays`, `tblScheduleType`, `tblSchedule`,
/// `tblUserSchedule`, `tblScheduleRoundingRule`, `tblRoundingRule`. Every
/// read counts only active, non-MFD rows and current links.
class ScheduleRepository {
  const ScheduleRepository(this._db);

  final SqlExecutor _db;

  /// Active, non-MFD days.
  Future<List<DayRow>> listDays() async {
    final rows = await _db.query(
      'SELECT dayID, dayName FROM tblDays WHERE dayActive = 1 AND dayMFD = 0 ORDER BY dayID',
    );
    return [for (final row in rows) (id: row.readInt('dayID'), name: row.readString('dayName'))];
  }

  /// Active employees who are in exactly one current, active group, with
  /// that group. Inactive or MFD employees and groups do not count.
  Future<List<SingleGroupMember>> singleGroupMembers() async {
    final rows = await _db.query(
      'SELECT ug.groupID, ug.userID FROM tblUserGroup ug '
      'JOIN tblGroup g ON g.groupID = ug.groupID AND g.groupActive = 1 AND g.groupMFD = 0 '
      'JOIN tblUser u ON u.userID = ug.userID AND u.userActive = 1 AND u.userMFD = 0 '
      'WHERE ${MembershipFilters.activeGroup('ug')} '
      'AND (SELECT COUNT(*) FROM tblUserGroup ug2 '
      ' JOIN tblGroup g2 ON g2.groupID = ug2.groupID AND g2.groupActive = 1 AND g2.groupMFD = 0 '
      ' WHERE ug2.userID = ug.userID AND ${MembershipFilters.activeGroup('ug2')}) = 1 '
      'ORDER BY ug.groupID, ug.userID',
    );
    return [for (final row in rows) (groupId: row.readInt('groupID'), userId: row.readInt('userID'))];
  }

  /// The current work-start, work-finish and break schedules of [userIds].
  Future<List<UserScheduleRow>> schedulesOf(Iterable<int> userIds) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return const [];
    final rows = await _db.query(
      'SELECT us.userID, s.scheduleID, st.scheduleTypeName, s.dayID, s.scheduleHrStart, s.scheduleMinStart, '
      's.scheduleHrStop, s.scheduleMinStop, s.scheduleMarginMin '
      'FROM tblUserSchedule us '
      'JOIN tblSchedule s ON s.scheduleID = us.scheduleID AND s.scheduleActive = 1 AND s.scheduleMFD = 0 '
      'JOIN tblScheduleType st ON st.scheduleTypeID = s.scheduleTypeID '
      ' AND st.scheduleTypeActive = 1 AND st.scheduleTypeMFD = 0 '
      'JOIN tblDays d ON d.dayID = s.dayID AND d.dayActive = 1 AND d.dayMFD = 0 '
      'WHERE ${MembershipFilters.activeSchedule('us')} '
      'AND us.userID IN (${_placeholders('u', ids.length)}) '
      'AND st.scheduleTypeName IN (${_placeholders('t', ScheduleTypeNames.all.length)}) '
      'ORDER BY us.userID, s.scheduleID',
      {..._params('u', ids), ..._params('t', ScheduleTypeNames.all)},
    );
    return [
      for (final row in rows)
        (
          userId: row.readInt('userID'),
          scheduleId: row.readInt('scheduleID'),
          typeName: row.readString('scheduleTypeName'),
          dayId: row.readInt('dayID'),
          startHour: row.readInt('scheduleHrStart'),
          startMinute: row.readInt('scheduleMinStart'),
          stopHour: row.readInt('scheduleHrStop'),
          stopMinute: row.readInt('scheduleMinStop'),
          marginMinutes: row.readInt('scheduleMarginMin'),
        ),
    ];
  }

  /// The active rounding rules currently linked to [scheduleIds].
  Future<List<ScheduleRuleRow>> rulesOf(Iterable<int> scheduleIds) async {
    final ids = scheduleIds.toSet().toList();
    if (ids.isEmpty) return const [];
    final rows = await _db.query(
      'SELECT srr.scheduleID, r.roundingRuleValueInMin, r.roundingRuleRoundUp '
      'FROM tblScheduleRoundingRule srr '
      'JOIN tblRoundingRule r ON r.roundingRuleID = srr.roundingRuleID '
      ' AND r.roundingRuleActive = 1 AND r.roundingRuleMFD = 0 '
      'WHERE srr.scheduleRoundingRuleActive = 1 AND srr.scheduleRoundingRuleMFD = 0 '
      'AND srr.scheduleID IN (${_placeholders('s', ids.length)}) '
      'ORDER BY srr.scheduleID, srr.scheduleRoundingRuleID',
      _params('s', ids),
    );
    return [
      for (final row in rows)
        (
          scheduleId: row.readInt('scheduleID'),
          intervalMinutes: row.readInt('roundingRuleValueInMin'),
          roundUp: row.readBool('roundingRuleRoundUp'),
        ),
    ];
  }

  static String _placeholders(String prefix, int count) => [for (var i = 0; i < count; i++) ':$prefix$i'].join(', ');

  static Map<String, Object?> _params(String prefix, List<Object?> values) => {
        for (final (i, value) in values.indexed) '$prefix$i': value,
      };
}

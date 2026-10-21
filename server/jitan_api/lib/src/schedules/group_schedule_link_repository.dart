import '../database/sql_executor.dart';
import 'schedule_names.dart';

/// A current `tblGroupSchedule` link to an active schedule row.
typedef GroupScheduleLink = ({int groupScheduleId, int groupId, int scheduleId});

/// A schedule row a group currently has, with its type name and day.
typedef GroupScheduleRow = ({
  int groupId,
  int scheduleId,
  String typeName,
  int dayId,
  int startHour,
  int startMinute,
  int stopHour,
  int stopMinute,
  int marginMinutes,
});

/// **PROPOSAL, not in IT's database** (ERD_GAPS GAP-15): `tblGroupSchedule`,
/// a group's own schedule rows. Exists only in the local development
/// database (`dev/local-db/proposals/gap15_group_schedule.sql`) and is used
/// only with `JITAN_DEV_GROUP_SCHEDULES=true`, which production refuses.
///
/// Links are switched off with `Active = 0, MFD = 1`, never deleted; a link
/// switched off earlier is switched on again (unique `groupID, scheduleID`).
class GroupScheduleLinkRepository {
  const GroupScheduleLinkRepository();

  /// Current links of [groupIds] to active schedules of the types [typeNames].
  Future<List<GroupScheduleLink>> currentLinks(SqlExecutor tx, List<int> groupIds, List<String> typeNames) async {
    if (groupIds.isEmpty) return const [];
    final rows = await tx.query(
      'SELECT gs.groupScheduleID, gs.groupID, gs.scheduleID FROM tblGroupSchedule gs '
      'JOIN tblSchedule s ON s.scheduleID = gs.scheduleID AND s.scheduleActive = 1 AND s.scheduleMFD = 0 '
      'JOIN tblScheduleType st ON st.scheduleTypeID = s.scheduleTypeID '
      'WHERE gs.groupScheduleActive = 1 AND gs.groupScheduleMFD = 0 '
      'AND gs.groupID IN (${_placeholders('g', groupIds.length)}) '
      'AND st.scheduleTypeName IN (${_placeholders('t', typeNames.length)}) '
      'ORDER BY gs.groupScheduleID',
      {..._params('g', groupIds), ..._params('t', typeNames)},
    );
    return [
      for (final row in rows)
        (
          groupScheduleId: row.readInt('groupScheduleID'),
          groupId: row.readInt('groupID'),
          scheduleId: row.readInt('scheduleID'),
        ),
    ];
  }

  /// Links [groupId] to [scheduleId]; the link's ID.
  Future<int> link(SqlExecutor tx, int groupId, int scheduleId) async {
    final existing = await tx.query(
      'SELECT groupScheduleID FROM tblGroupSchedule WHERE groupID = :g AND scheduleID = :s',
      {'g': groupId, 's': scheduleId},
    );
    if (existing.isNotEmpty) {
      final id = existing.first.readInt('groupScheduleID');
      await tx.execute(
        'UPDATE tblGroupSchedule SET groupScheduleActive = 1, groupScheduleMFD = 0 WHERE groupScheduleID = :id',
        {'id': id},
      );
      return id;
    }
    return (await tx.execute(
      'INSERT INTO tblGroupSchedule (groupID, scheduleID, groupScheduleActive, groupScheduleMFD) VALUES (:g, :s, 1, 0)',
      {'g': groupId, 's': scheduleId},
    ))
        .lastInsertId;
  }

  /// Switches the links [groupScheduleIds] off.
  Future<void> removeLinks(SqlExecutor tx, List<int> groupScheduleIds) async {
    if (groupScheduleIds.isEmpty) return;
    await tx.execute(
      'UPDATE tblGroupSchedule SET groupScheduleActive = 0, groupScheduleMFD = 1 '
      'WHERE groupScheduleID IN (${_placeholders('l', groupScheduleIds.length)})',
      _params('l', groupScheduleIds),
    );
  }

  /// Of [scheduleIds], those a current group link still uses.
  Future<Set<int>> stillLinked(SqlExecutor tx, List<int> scheduleIds) async {
    if (scheduleIds.isEmpty) return const {};
    final rows = await tx.query(
      'SELECT DISTINCT scheduleID FROM tblGroupSchedule WHERE groupScheduleActive = 1 AND groupScheduleMFD = 0 '
      'AND scheduleID IN (${_placeholders('s', scheduleIds.length)})',
      _params('s', scheduleIds),
    );
    return {for (final row in rows) row.readInt('scheduleID')};
  }

  /// Every active group's current work-start, work-finish and break rows.
  Future<List<GroupScheduleRow>> rowsOfGroups(SqlExecutor db) async {
    final rows = await db.query(
      'SELECT gs.groupID, s.scheduleID, st.scheduleTypeName, s.dayID, s.scheduleHrStart, s.scheduleMinStart, '
      's.scheduleHrStop, s.scheduleMinStop, s.scheduleMarginMin '
      'FROM tblGroupSchedule gs '
      'JOIN tblGroup g ON g.groupID = gs.groupID AND g.groupActive = 1 AND g.groupMFD = 0 '
      'JOIN tblSchedule s ON s.scheduleID = gs.scheduleID AND s.scheduleActive = 1 AND s.scheduleMFD = 0 '
      'JOIN tblScheduleType st ON st.scheduleTypeID = s.scheduleTypeID '
      ' AND st.scheduleTypeActive = 1 AND st.scheduleTypeMFD = 0 '
      'JOIN tblDays d ON d.dayID = s.dayID AND d.dayActive = 1 AND d.dayMFD = 0 '
      'WHERE gs.groupScheduleActive = 1 AND gs.groupScheduleMFD = 0 '
      'AND st.scheduleTypeName IN (${_placeholders('t', ScheduleTypeNames.all.length)}) '
      'ORDER BY gs.groupID, s.scheduleID',
      _params('t', ScheduleTypeNames.all),
    );
    return [
      for (final row in rows)
        (
          groupId: row.readInt('groupID'),
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

  static String _placeholders(String prefix, int count) => [for (var i = 0; i < count; i++) ':$prefix$i'].join(', ');

  static Map<String, Object?> _params(String prefix, List<Object?> values) => {
        for (final (i, value) in values.indexed) '$prefix$i': value,
      };
}

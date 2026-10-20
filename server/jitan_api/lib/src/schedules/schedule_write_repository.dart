import '../database/sql_executor.dart';
import '../employees/membership_filters.dart';

/// An employee in a group, with how many current, active groups they are in.
typedef GroupEmployee = ({int userId, int groupCount});

/// A current `tblUserSchedule` link to an active schedule of a given type.
typedef ScheduleLink = ({int userScheduleId, int userId, int scheduleId});

/// What a schedule row holds, for comparing a save with what exists.
typedef ScheduleShape = ({
  int scheduleId,
  String typeName,
  int dayId,
  int startMinutes,
  int stopMinutes,
  int marginMinutes,
  int? intervalMinutes,
  bool? roundUp,
});

/// Writes for saving a group's schedules. Every method runs in the caller's
/// transaction. Nothing is deleted: links and rows are switched off with
/// `Active = 0, MFD = 1` and stay as history.
class ScheduleWriteRepository {
  const ScheduleWriteRepository();

  /// Locks the group row (first statement of the transaction, so saves of
  /// one group run one after the other). `false` when the group does not
  /// exist or is inactive or MFD.
  Future<bool> lockGroup(SqlExecutor tx, int groupId) async => (await tx.query(
        'SELECT groupID FROM tblGroup WHERE groupID = :id AND groupActive = 1 AND groupMFD = 0 FOR UPDATE',
        {'id': groupId},
      ))
          .isNotEmpty;

  /// Active employees currently in [groupId], with their number of current,
  /// active groups.
  Future<List<GroupEmployee>> groupEmployees(SqlExecutor tx, int groupId) async {
    final rows = await tx.query(
      'SELECT ug.userID, (SELECT COUNT(*) FROM tblUserGroup ug2 '
      ' JOIN tblGroup g2 ON g2.groupID = ug2.groupID AND g2.groupActive = 1 AND g2.groupMFD = 0 '
      ' WHERE ug2.userID = ug.userID AND ${MembershipFilters.activeGroup('ug2')}) AS groupCount '
      'FROM tblUserGroup ug '
      'JOIN tblUser u ON u.userID = ug.userID AND u.userActive = 1 AND u.userMFD = 0 '
      'WHERE ug.groupID = :groupId AND ${MembershipFilters.activeGroup('ug')} '
      'ORDER BY ug.userID',
      {'groupId': groupId},
    );
    return [for (final row in rows) (userId: row.readInt('userID'), groupCount: row.readInt('groupCount'))];
  }

  /// The current, active groups of [userId].
  Future<List<int>> groupsOf(SqlExecutor tx, int userId) async => [
        for (final row in await tx.query(
          'SELECT ug.groupID FROM tblUserGroup ug '
          'JOIN tblGroup g ON g.groupID = ug.groupID AND g.groupActive = 1 AND g.groupMFD = 0 '
          'WHERE ug.userID = :u AND ${MembershipFilters.activeGroup('ug')} ORDER BY ug.groupID',
          {'u': userId},
        ))
          row.readInt('groupID'),
      ];

  /// Current links of [userIds] to active schedules of the types [typeNames].
  Future<List<ScheduleLink>> currentLinks(SqlExecutor tx, List<int> userIds, List<String> typeNames) async {
    if (userIds.isEmpty) return const [];
    final rows = await tx.query(
      'SELECT us.userScheduleID, us.userID, us.scheduleID FROM tblUserSchedule us '
      'JOIN tblSchedule s ON s.scheduleID = us.scheduleID AND s.scheduleActive = 1 AND s.scheduleMFD = 0 '
      'JOIN tblScheduleType st ON st.scheduleTypeID = s.scheduleTypeID '
      'WHERE ${MembershipFilters.activeSchedule('us')} '
      'AND us.userID IN (${_placeholders('u', userIds.length)}) '
      'AND st.scheduleTypeName IN (${_placeholders('t', typeNames.length)}) '
      'ORDER BY us.userScheduleID',
      {..._params('u', userIds), ..._params('t', typeNames)},
    );
    return [
      for (final row in rows)
        (userScheduleId: row.readInt('userScheduleID'), userId: row.readInt('userID'), scheduleId: row.readInt('scheduleID')),
    ];
  }

  /// The rows [scheduleIds] with their one current, active rounding rule
  /// (`null` when they have none or several).
  Future<List<ScheduleShape>> shapes(SqlExecutor tx, List<int> scheduleIds) async {
    if (scheduleIds.isEmpty) return const [];
    final rows = await tx.query(
      'SELECT s.scheduleID, st.scheduleTypeName, s.dayID, s.scheduleHrStart, s.scheduleMinStart, s.scheduleHrStop, '
      's.scheduleMinStop, s.scheduleMarginMin, '
      '(SELECT COUNT(*) FROM tblScheduleRoundingRule srr JOIN tblRoundingRule r ON r.roundingRuleID = srr.roundingRuleID '
      '  AND r.roundingRuleActive = 1 AND r.roundingRuleMFD = 0 '
      '  WHERE srr.scheduleID = s.scheduleID AND srr.scheduleRoundingRuleActive = 1 AND srr.scheduleRoundingRuleMFD = 0) '
      ' AS ruleCount, '
      '(SELECT MIN(r.roundingRuleValueInMin) FROM tblScheduleRoundingRule srr JOIN tblRoundingRule r '
      '  ON r.roundingRuleID = srr.roundingRuleID AND r.roundingRuleActive = 1 AND r.roundingRuleMFD = 0 '
      '  WHERE srr.scheduleID = s.scheduleID AND srr.scheduleRoundingRuleActive = 1 AND srr.scheduleRoundingRuleMFD = 0) '
      ' AS intervalMinutes, '
      '(SELECT MIN(r.roundingRuleRoundUp) FROM tblScheduleRoundingRule srr JOIN tblRoundingRule r '
      '  ON r.roundingRuleID = srr.roundingRuleID AND r.roundingRuleActive = 1 AND r.roundingRuleMFD = 0 '
      '  WHERE srr.scheduleID = s.scheduleID AND srr.scheduleRoundingRuleActive = 1 AND srr.scheduleRoundingRuleMFD = 0) '
      ' AS roundUp '
      'FROM tblSchedule s JOIN tblScheduleType st ON st.scheduleTypeID = s.scheduleTypeID '
      'WHERE s.scheduleID IN (${_placeholders('s', scheduleIds.length)}) ORDER BY s.scheduleID',
      _params('s', scheduleIds),
    );
    return [
      for (final row in rows)
        (
          scheduleId: row.readInt('scheduleID'),
          typeName: row.readString('scheduleTypeName'),
          dayId: row.readInt('dayID'),
          startMinutes: row.readInt('scheduleHrStart') * 60 + row.readInt('scheduleMinStart'),
          stopMinutes: row.readInt('scheduleHrStop') * 60 + row.readInt('scheduleMinStop'),
          marginMinutes: row.readInt('scheduleMarginMin'),
          intervalMinutes: row.readInt('ruleCount') == 1 ? row.readOptionalInt('intervalMinutes') : null,
          roundUp: row.readInt('ruleCount') == 1 ? row.readOptionalBool('roundUp') : null,
        ),
    ];
  }

  /// The IDs of the active `tblScheduleType` rows named [name]; the caller
  /// treats none, or several, as a configuration error.
  Future<List<int>> typeIds(SqlExecutor tx, String name) async => [
        for (final row in await tx.query(
          'SELECT scheduleTypeID FROM tblScheduleType WHERE scheduleTypeName = :name '
          'AND scheduleTypeActive = 1 AND scheduleTypeMFD = 0 ORDER BY scheduleTypeID',
          {'name': name},
        ))
          row.readInt('scheduleTypeID'),
      ];

  Future<int> insertSchedule(
    SqlExecutor tx, {
    required int typeId,
    required int dayId,
    required int startMinutes,
    required int stopMinutes,
    required int marginMinutes,
  }) async =>
      (await tx.execute(
        'INSERT INTO tblSchedule (scheduleTypeID, dayID, scheduleHrStart, scheduleMinStart, scheduleHrStop, '
        'scheduleMinStop, scheduleMarginMin, scheduleActive, scheduleMFD) '
        'VALUES (:type, :day, :hs, :ms, :he, :me, :margin, 1, 0)',
        {
          'type': typeId,
          'day': dayId,
          'hs': startMinutes ~/ 60,
          'ms': startMinutes % 60,
          'he': stopMinutes ~/ 60,
          'me': stopMinutes % 60,
          'margin': marginMinutes,
        },
      ))
          .lastInsertId;

  Future<int> insertRule(SqlExecutor tx, {required int intervalMinutes, required bool roundUp}) async => (await tx.execute(
        'INSERT INTO tblRoundingRule (roundingRuleValueInMin, roundingRuleRoundUp, roundingRuleActive, roundingRuleMFD) '
        'VALUES (:v, :up, 1, 0)',
        {'v': intervalMinutes, 'up': roundUp},
      ))
          .lastInsertId;

  Future<int> linkRule(SqlExecutor tx, int scheduleId, int ruleId) async => (await tx.execute(
        'INSERT INTO tblScheduleRoundingRule (scheduleID, roundingRuleID, scheduleRoundingRuleActive, '
        'scheduleRoundingRuleMFD) VALUES (:s, :r, 1, 0)',
        {'s': scheduleId, 'r': ruleId},
      ))
          .lastInsertId;

  /// Gives [userId] the schedule [scheduleId]: reactivates their switched-off
  /// link to it when there is one (the unique pair allows one row per pair),
  /// inserts a new link otherwise.
  Future<int> linkUser(SqlExecutor tx, int userId, int scheduleId) async {
    final existing = await tx.query(
      'SELECT userScheduleID FROM tblUserSchedule WHERE userID = :u AND scheduleID = :s',
      {'u': userId, 's': scheduleId},
    );
    if (existing.isNotEmpty) {
      final id = existing.single.readInt('userScheduleID');
      await tx.execute(
        'UPDATE tblUserSchedule SET userScheduleActive = 1, userScheduleMFD = 0 WHERE userScheduleID = :id',
        {'id': id},
      );
      return id;
    }
    return (await tx.execute(
      'INSERT INTO tblUserSchedule (userID, scheduleID, userScheduleActive, userScheduleMFD) VALUES (:u, :s, 1, 0)',
      {'u': userId, 's': scheduleId},
    ))
        .lastInsertId;
  }

  /// Switches the links [userScheduleIds] off.
  Future<void> removeLinks(SqlExecutor tx, List<int> userScheduleIds) async {
    if (userScheduleIds.isEmpty) return;
    await tx.execute(
      'UPDATE tblUserSchedule SET userScheduleActive = 0, userScheduleMFD = 1 '
      'WHERE userScheduleID IN (${_placeholders('l', userScheduleIds.length)})',
      _params('l', userScheduleIds),
    );
  }

  /// Of [scheduleIds], those no current link uses any more.
  Future<List<int>> unused(SqlExecutor tx, List<int> scheduleIds) async {
    if (scheduleIds.isEmpty) return const [];
    final rows = await tx.query(
      'SELECT s.scheduleID FROM tblSchedule s '
      'WHERE s.scheduleID IN (${_placeholders('s', scheduleIds.length)}) AND s.scheduleActive = 1 AND s.scheduleMFD = 0 '
      'AND NOT EXISTS (SELECT 1 FROM tblUserSchedule us WHERE us.scheduleID = s.scheduleID '
      ' AND ${MembershipFilters.activeSchedule('us')}) ORDER BY s.scheduleID',
      _params('s', scheduleIds),
    );
    return [for (final row in rows) row.readInt('scheduleID')];
  }

  /// Switches the schedule rows [scheduleIds] off, with their rounding-rule
  /// links, and the rules no active link uses any more.
  Future<void> deactivateSchedules(SqlExecutor tx, List<int> scheduleIds) async {
    if (scheduleIds.isEmpty) return;
    final params = _params('s', scheduleIds);
    final ids = _placeholders('s', scheduleIds.length);
    final ruleIds = [
      for (final row in await tx.query(
        'SELECT DISTINCT roundingRuleID FROM tblScheduleRoundingRule WHERE scheduleID IN ($ids) '
        'AND scheduleRoundingRuleActive = 1 AND scheduleRoundingRuleMFD = 0',
        params,
      ))
        row.readInt('roundingRuleID'),
    ];
    await tx.execute('UPDATE tblSchedule SET scheduleActive = 0, scheduleMFD = 1 WHERE scheduleID IN ($ids)', params);
    await tx.execute(
      'UPDATE tblScheduleRoundingRule SET scheduleRoundingRuleActive = 0, scheduleRoundingRuleMFD = 1 '
      'WHERE scheduleID IN ($ids) AND scheduleRoundingRuleActive = 1 AND scheduleRoundingRuleMFD = 0',
      params,
    );
    if (ruleIds.isEmpty) return;
    await tx.execute(
      'UPDATE tblRoundingRule r SET r.roundingRuleActive = 0, r.roundingRuleMFD = 1 '
      'WHERE r.roundingRuleID IN (${_placeholders('r', ruleIds.length)}) '
      'AND NOT EXISTS (SELECT 1 FROM tblScheduleRoundingRule srr WHERE srr.roundingRuleID = r.roundingRuleID '
      ' AND srr.scheduleRoundingRuleActive = 1 AND srr.scheduleRoundingRuleMFD = 0)',
      _params('r', ruleIds),
    );
  }

  static String _placeholders(String prefix, int count) => [for (var i = 0; i < count; i++) ':$prefix$i'].join(', ');

  static Map<String, Object?> _params(String prefix, List<Object?> values) => {
        for (final (i, value) in values.indexed) '$prefix$i': value,
      };
}

import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';

import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_summary_text.dart';

/// The "Schedule" of a group in the groups list: its days and hours
/// ("Mon–Fri 08:00–16:30"), or why it has none.
String groupScheduleText(Translations t, GroupSchedule? schedule) => switch (schedule) {
  null => t.t(AdminTextKeys.groupsScheduleNone),
  GroupSchedule(status: GroupScheduleStatus.noSingleGroupEmployees) => t.t(AdminTextKeys.groupsScheduleNoOwn),
  GroupSchedule(status: GroupScheduleStatus.employeesDiffer) => t.t(AdminTextKeys.groupsScheduleDiffer),
  GroupSchedule(status: GroupScheduleStatus.noSchedule) => t.t(AdminTextKeys.groupsScheduleNone),
  GroupSchedule(:final variants) when variants.single.workDays.isEmpty => t.t(AdminTextKeys.groupsScheduleNone),
  GroupSchedule(:final variants) => workHoursDaysSummary(t, variants.single),
};

/// Whether [schedule] is the group's own work hours (not "No schedule yet",
/// "No schedule of its own" or "Different hours"), shown in ink, not muted.
bool groupHasOwnHours(GroupSchedule schedule) =>
    schedule.status == GroupScheduleStatus.configured && schedule.variants.single.workDays.isNotEmpty;

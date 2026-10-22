import 'package:jitan_models/jitan_models.dart';

/// The two kinds of schedule HR sets for a group.
enum ScheduleKind { workHours, breaks }

/// What a row's Status column shows.
enum ScheduleRowStatus {
  /// Every employee the group's schedule applies to has these rows.
  active,

  /// Those employees have different rows; HR saves one set for all of them.
  employeesDiffer,
}

/// One line of the Schedules table (Figma `HR / Schedules — One row per
/// group` 1458:2): one group's work hours, break and rounding together. A
/// click opens the group's page, where its schedule is managed.
///
/// There is no schedule name or group link in the ERD: a row is derived
/// from what the server found on the group's employees ([GroupSchedule]).
class ScheduleRow {
  const ScheduleRow({required this.schedule, required this.status});

  final GroupSchedule schedule;
  final ScheduleRowStatus status;

  GroupSummary get group => schedule.group;

  /// The schedule shown: the only variant, or `null` when the employees differ.
  ScheduleVariant? get variant => status == ScheduleRowStatus.active ? schedule.variants.single : null;

  bool get hasWorkHours => hasSchedule(schedule, ScheduleKind.workHours);
  bool get hasBreaks => hasSchedule(schedule, ScheduleKind.breaks);
}

/// The table rows for [groups]: one per group that has work hours or a
/// break. Groups with no schedule have no row (HR adds one with "Add
/// schedule", or on the group's page).
List<ScheduleRow> scheduleRowsOf(List<GroupSchedule> groups) => [
  for (final group in groups)
    if (hasSchedule(group, ScheduleKind.workHours) || hasSchedule(group, ScheduleKind.breaks))
      switch (group.status) {
        GroupScheduleStatus.configured => ScheduleRow(schedule: group, status: ScheduleRowStatus.active),
        _ => ScheduleRow(schedule: group, status: ScheduleRowStatus.employeesDiffer),
      },
];

/// Whether [group] already has a schedule of [kind], so "Add schedule"
/// should edit it instead of creating a second one.
bool hasSchedule(GroupSchedule group, ScheduleKind kind) =>
    (group.status == GroupScheduleStatus.configured || group.status == GroupScheduleStatus.employeesDiffer) &&
    switch (kind) {
      ScheduleKind.workHours => group.variants.any((v) => v.workDays.isNotEmpty),
      ScheduleKind.breaks => group.variants.any((v) => v.breaks.isNotEmpty),
    };

/// The toolbar's search and filters. `null` filter = all.
class ScheduleFilter {
  const ScheduleFilter({this.search = '', this.groupId, this.status});

  final String search;
  final int? groupId;
  final ScheduleRowStatus? status;

  /// Search matches the group name, ignoring case.
  bool matches(ScheduleRow row) =>
      (groupId == null || row.group.id == groupId) &&
      (status == null || row.status == status) &&
      (search.isEmpty || row.group.name.toLowerCase().contains(search.toLowerCase()));

  bool get isEmpty => search.isEmpty && groupId == null && status == null;
}

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

/// One line of the Schedules table: one kind of schedule of one group.
///
/// There is no schedule name or group link in the ERD: a row is derived
/// from what the server found on the group's employees ([GroupSchedule]).
class ScheduleRow {
  const ScheduleRow({required this.schedule, required this.kind, required this.status});

  final GroupSchedule schedule;
  final ScheduleKind kind;
  final ScheduleRowStatus status;

  GroupSummary get group => schedule.group;

  /// The schedule shown: the only variant, or `null` when the employees differ.
  ScheduleVariant? get variant => status == ScheduleRowStatus.active ? schedule.variants.single : null;
}

/// The table rows for [groups]: a Work hours and a Break row per group that
/// has them. Groups with no schedule have no row (HR adds one with "Add
/// schedule").
List<ScheduleRow> scheduleRowsOf(List<GroupSchedule> groups) => [
  for (final group in groups)
    ...switch (group.status) {
      GroupScheduleStatus.configured => [
        if (group.variants.single.workDays.isNotEmpty)
          ScheduleRow(schedule: group, kind: ScheduleKind.workHours, status: ScheduleRowStatus.active),
        if (group.variants.single.breaks.isNotEmpty)
          ScheduleRow(schedule: group, kind: ScheduleKind.breaks, status: ScheduleRowStatus.active),
      ],
      GroupScheduleStatus.employeesDiffer => [
        if (group.variants.any((v) => v.workDays.isNotEmpty))
          ScheduleRow(schedule: group, kind: ScheduleKind.workHours, status: ScheduleRowStatus.employeesDiffer),
        if (group.variants.any((v) => v.breaks.isNotEmpty))
          ScheduleRow(schedule: group, kind: ScheduleKind.breaks, status: ScheduleRowStatus.employeesDiffer),
      ],
      GroupScheduleStatus.noSchedule || GroupScheduleStatus.noSingleGroupEmployees => const <ScheduleRow>[],
    },
];

/// Whether [group] already has a schedule of [kind], so "Add schedule"
/// should edit it instead of creating a second one.
bool hasSchedule(GroupSchedule group, ScheduleKind kind) => switch (kind) {
  ScheduleKind.workHours => group.variants.any((v) => v.workDays.isNotEmpty),
  ScheduleKind.breaks => group.variants.any((v) => v.breaks.isNotEmpty),
};

/// The toolbar's search and filters. `null` filter = all.
class ScheduleFilter {
  const ScheduleFilter({this.search = '', this.kind, this.groupId, this.status});

  final String search;
  final ScheduleKind? kind;
  final int? groupId;
  final ScheduleRowStatus? status;

  /// Search matches the group name, ignoring case.
  bool matches(ScheduleRow row) =>
      (kind == null || row.kind == kind) &&
      (groupId == null || row.group.id == groupId) &&
      (status == null || row.status == status) &&
      (search.isEmpty || row.group.name.toLowerCase().contains(search.toLowerCase()));

  bool get isEmpty => search.isEmpty && kind == null && groupId == null && status == null;
}

import 'package:jitan_models/jitan_models.dart';

import '../activities/activity_service.dart';
import '../audit/audit_event.dart';
import '../locations/location_type_names.dart';
import '../schedules/schedule_names.dart';
import '../terminals/terminal_repository.dart';
import '../time_registration/time_reg_type_names.dart';

/// Where a fixed list lives and which entries Jitan reads from it by name.
/// Table and column names are fixed strings written here, never from a
/// request (ENGINEERING_RULES §28a.1).
class FixedListTable {
  const FixedListTable({
    required this.table,
    required this.nameColumn,
    this.activeColumn,
    this.mfdColumn,
    this.required = const [],
    this.reference,
    this.addable = true,
  });

  final String table;
  final String nameColumn;

  /// `null` for a table without Active/MFD (`tblEventType`).
  final String? activeColumn;
  final String? mfdColumn;

  /// The names Jitan reads, in the order the page shows them.
  final List<String> required;

  /// The `tblEventLog` column that names an added row, if there is one.
  final EventLogReference? reference;

  /// Free lists (access roles, languages) are only counted here.
  final bool addable;
}

abstract final class FixedListCatalog {
  static List<String> get _registrationTypes => [
    for (final boundary in RegistrationBoundary.values) ...[
      for (final method in TimeRegistrationMethod.values) TimeRegTypeNames.actual(boundary, method),
      TimeRegTypeNames.rounded(boundary),
      TimeRegTypeNames.corrected(boundary),
    ],
    ...ActivityService.typeNames,
  ];

  static FixedListTable of(FixedListKind kind) => switch (kind) {
    FixedListKind.registrationTypes => FixedListTable(
      table: 'tblTimeRegType',
      nameColumn: 'timeRegTypeName',
      activeColumn: 'timeRegTypeActive',
      mfdColumn: 'timeRegTypeMFD',
      required: _registrationTypes,
      reference: EventLogReference.timeRegType,
    ),
    FixedListKind.scheduleTypes => const FixedListTable(
      table: 'tblScheduleType',
      nameColumn: 'scheduleTypeName',
      activeColumn: 'scheduleTypeActive',
      mfdColumn: 'scheduleTypeMFD',
      required: ScheduleTypeNames.all,
      reference: EventLogReference.scheduleType,
    ),
    FixedListKind.days => FixedListTable(
      table: 'tblDays',
      nameColumn: 'dayName',
      activeColumn: 'dayActive',
      mfdColumn: 'dayMFD',
      required: DayNames.all.toList(),
      reference: EventLogReference.day,
    ),
    FixedListKind.accessRoles => const FixedListTable(
      table: 'tblCredGroup',
      nameColumn: 'credGroupName',
      activeColumn: 'credGroupActive',
      mfdColumn: 'credGroupMFD',
      addable: false,
    ),
    FixedListKind.languages => const FixedListTable(
      table: 'tblLanguage',
      nameColumn: 'languageName',
      activeColumn: 'languageActive',
      mfdColumn: 'languageMFD',
      addable: false,
    ),
    FixedListKind.placeKinds => const FixedListTable(
      table: 'tblLocationType',
      nameColumn: 'locationTypeName',
      activeColumn: 'locationTypeActive',
      mfdColumn: 'locationTypeMFD',
      required: LocationTypeNames.all,
      reference: EventLogReference.locationType,
    ),
    FixedListKind.terminalKinds => const FixedListTable(
      table: 'tblDeviceType',
      nameColumn: 'deviceTypeName',
      activeColumn: 'deviceTypeActive',
      mfdColumn: 'deviceTypeMFD',
      required: [TerminalRepository.officeTypeName, TerminalRepository.vehicleTypeName],
      reference: EventLogReference.deviceType,
    ),
    FixedListKind.auditNames => FixedListTable(
      table: 'tblEventType',
      nameColumn: 'eventTypeName',
      required: [for (final type in AuditEventType.values) type.typeName],
    ),
  };
}

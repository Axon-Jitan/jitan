import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Where an employee stands, in one word (Figma `1531:2`): active and set
/// up, active but not set up yet (onboarding not done, `userPassword IS
/// NULL`), or inactive.
enum EmployeeStanding {
  active,
  notSetUp,
  inactive;

  static EmployeeStanding of({required bool isActive, required bool isActivated}) =>
      !isActive ? inactive : (isActivated ? active : notSetUp);

  static EmployeeStanding ofSummary(EmployeeSummary e) => of(isActive: e.isActive, isActivated: e.isActivated);

  String label(BuildContext context) => context.t(switch (this) {
    active => CommonTextKeys.statusActive,
    notSetUp => AdminTextKeys.employeeNotSetUp,
    inactive => CommonTextKeys.statusInactive,
  });

  Color get color => switch (this) {
    active => JitanColors.success,
    notSetUp => JitanColors.warning,
    inactive => JitanColors.inkMuted,
  };
}

/// The status buttons above the list: everyone, or one standing.
enum EmployeeStatusFilter {
  all,
  active,
  notSetUp,
  inactive;

  bool lets(EmployeeSummary e) => switch (this) {
    all => true,
    active => EmployeeStanding.ofSummary(e) == EmployeeStanding.active,
    notSetUp => EmployeeStanding.ofSummary(e) == EmployeeStanding.notSetUp,
    inactive => EmployeeStanding.ofSummary(e) == EmployeeStanding.inactive,
  };
}

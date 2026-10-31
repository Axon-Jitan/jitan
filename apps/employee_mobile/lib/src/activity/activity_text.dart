import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';

/// The words of an activity.
abstract final class ActivityText {
  static String kind(BuildContext context, ActivityKind kind) => context.t(switch (kind) {
    ActivityKind.work => EmployeeTextKeys.activityWork,
    ActivityKind.clientOnSite => EmployeeTextKeys.activityOnSite,
    ActivityKind.clientInHouse => EmployeeTextKeys.activityInHouse,
    ActivityKind.internal => EmployeeTextKeys.activityInternal,
    ActivityKind.transport => EmployeeTextKeys.activityTransport,
  });

  /// "Client project · Almeco".
  static String project(BuildContext context, MyProject project) => context.t(
    project.isClient ? EmployeeTextKeys.activityClientProject : EmployeeTextKeys.activityInternalProject,
    args: {'company': project.companyName},
  );
}

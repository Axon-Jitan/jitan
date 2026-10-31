import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// The words of the Projects pages.
abstract final class ProjectText {
  /// `tblProjectStatus` row shown as running, in the green of "Active".
  static const _runningStatus = 'Active';

  static bool isRunning(ProjectChoice status) => status.name == _runningStatus;

  /// "19 October 2026".
  static String date(BuildContext context, DateTime date) =>
      '${date.day} ${context.t(CommonTextKeys.monthLong[date.month - 1])} ${date.year}';

  static String employeeName(String? first, String? last, String code) {
    final name = [first, last].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    return name.isEmpty ? code : name;
  }
}

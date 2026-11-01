import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_web_text_keys.dart';

/// The words and numbers every page shares.
abstract final class WebText {
  /// "4h 18m", "8h".
  static String duration(BuildContext context, int minutes) {
    final m = minutes % 60;
    return context.t(
      m == 0 ? EmployeeWebTextKeys.hours : EmployeeWebTextKeys.hoursMinutes,
      args: {'hours': minutes ~/ 60, 'minutes': m.toString().padLeft(2, '0')},
    );
  }

  static String kilometres(BuildContext context, int metres) =>
      context.t(EmployeeWebTextKeys.kilometres, args: {'km': (metres / 1000).round()});

  /// "November 2026".
  static String month(BuildContext context, DateTime month) =>
      '${context.t(CommonTextKeys.monthLong[month.month - 1])} ${month.year}';

  /// "Mon 2 November".
  static String day(BuildContext context, DateTime date) =>
      '${context.t(CommonTextKeys.weekdayShort[date.weekday - 1])} ${date.day} '
      '${context.t(CommonTextKeys.monthLong[date.month - 1])}';

  /// "Wednesday 4 November".
  static String longDay(BuildContext context, DateTime date) =>
      '${context.t(CommonTextKeys.weekdayLong[date.weekday - 1])} ${date.day} '
      '${context.t(CommonTextKeys.monthLong[date.month - 1])}';

  /// "19 October 2026", from `yyyy-MM-dd`.
  static String date(BuildContext context, String date) {
    final parsed = DateTime.parse(date);
    return '${parsed.day} ${context.t(CommonTextKeys.monthLong[parsed.month - 1])} ${parsed.year}';
  }

  /// "On site · Almeco".
  static String project(BuildContext context, MyProject project) => context.t(
    EmployeeWebTextKeys.projectDetail,
    args: {
      'kind': context.t(project.isClient ? EmployeeWebTextKeys.entryOnSite : EmployeeWebTextKeys.entryInternal),
      'company': project.companyName,
    },
  );

  static String kind(BuildContext context, ActivityKind kind) => context.t(switch (kind) {
    ActivityKind.work => EmployeeWebTextKeys.entryWork,
    ActivityKind.clientOnSite => EmployeeWebTextKeys.entryOnSite,
    ActivityKind.clientInHouse => EmployeeWebTextKeys.entryInHouse,
    ActivityKind.internal => EmployeeWebTextKeys.entryInternal,
    ActivityKind.transport => EmployeeWebTextKeys.entryTransport,
  });
}

/// A white card with rows divided by a thin line (Figma `1499:19`, `1499:839`).
class WebList extends StatelessWidget {
  const WebList({super.key, required this.rows, this.color = JitanColors.surface, this.radius = 18});

  final List<Widget> rows;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, color: JitanColors.inputBorder),
          row,
        ],
      ],
    ),
  );
}

/// One label and its value, in a list.
class WebLabelRow extends StatelessWidget {
  const WebLabelRow({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      spacing: 16,
      children: [
        Text(label, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: JitanTextStyles.tableCell.copyWith(fontWeight: FontWeight.w500, color: valueColor),
          ),
        ),
      ],
    ),
  );
}

/// "Jitan can't be reached" (Figma `1501:518`).
class WebNoConnection extends StatelessWidget {
  const WebNoConnection({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.t(EmployeeWebTextKeys.noConnectionTitle), textAlign: TextAlign.center, style: JitanTextStyles.modalTitle),
          const SizedBox(height: 6),
          Text(context.t(EmployeeWebTextKeys.noConnectionText), textAlign: TextAlign.center, style: JitanTextStyles.stateMessage),
          const SizedBox(height: 20),
          JitanSecondaryButton(label: context.t(EmployeeWebTextKeys.tryAgain), onPressed: onRetry),
        ],
      ),
    ),
  );
}

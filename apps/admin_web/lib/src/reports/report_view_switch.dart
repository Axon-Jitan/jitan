import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Which report the Reports page shows.
enum ReportView { employees, projects }

/// "Employees | Projects" under the page title (Figma `1515:2`): the chosen
/// one sits on a white pill.
class ReportViewSwitch extends StatelessWidget {
  const ReportViewSwitch({super.key, required this.value, required this.onChanged});

  final ReportView value;
  final ValueChanged<ReportView> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: DecoratedBox(
      decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(11)),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            for (final (view, key) in [
              (ReportView.employees, AdminTextKeys.reportViewEmployees),
              (ReportView.projects, AdminTextKeys.reportViewProjects),
            ])
              _Option(label: context.t(key), selected: view == value, onTap: () => onChanged(view)),
          ],
        ),
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? JitanColors.surface : Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      shadowColor: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: JitanColors.ink.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1))],
                )
              : null,
          child: Text(
            label,
            style: JitanTextStyles.tableCell.copyWith(
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? JitanColors.ink : JitanColors.inkMuted,
            ),
          ),
        ),
      ),
    ),
  );
}

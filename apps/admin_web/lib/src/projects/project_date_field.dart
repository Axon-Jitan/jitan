import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'project_text.dart';

/// A date in the project form (Figma `1077:74`): a field that opens one month
/// under itself. [hint] shows while nothing is chosen.
class ProjectDateField extends StatefulWidget {
  const ProjectDateField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final String hint;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  @override
  State<ProjectDateField> createState() => _ProjectDateFieldState();
}

class _ProjectDateFieldState extends State<ProjectDateField> {
  final _menu = MenuController();
  late DateTime _month = _monthOf(widget.value ?? DateTime.now());

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  void _pick(DateTime day) {
    widget.onChanged(day);
    _menu.close();
  }

  Widget _calendar() => StatefulBuilder(
    builder: (context, setMenu) {
      void move(int by) => setMenu(() => _month = DateTime(_month.year, _month.month + by));
      final value = widget.value;
      return SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${context.t(CommonTextKeys.monthLong[_month.month - 1])} ${_month.year}',
                      style: JitanTextStyles.tableCellStrong,
                    ),
                  ),
                  IconButton(
                    tooltip: context.t(AdminTextKeys.periodPreviousMonth),
                    onPressed: () => move(-1),
                    icon: const Icon(Icons.chevron_left, size: 18),
                  ),
                  IconButton(
                    tooltip: context.t(AdminTextKeys.periodNextMonth),
                    onPressed: () => move(1),
                    icon: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
              JitanMonthGrid(month: _month, from: value, to: value, onPick: _pick),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return JitanFieldLabel(
      label: widget.label,
      child: MenuAnchor(
        controller: _menu,
        alignmentOffset: const Offset(0, 6),
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(JitanColors.surface),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
        menuChildren: [_calendar()],
        child: InkWell(
          borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
          onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
          child: InputDecorator(
            isEmpty: value == null,
            decoration: jitanFieldDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
            ).copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: JitanColors.inkMuted)),
            child: Text(value == null ? '' : ProjectText.date(context, value), style: JitanTextStyles.inputText),
          ),
        ),
      ),
    );
  }
}

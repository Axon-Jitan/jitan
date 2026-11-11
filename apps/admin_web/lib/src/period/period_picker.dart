import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'dashboard_period.dart';
import 'dashboard_text.dart';

/// Opens the period picker (Figma `1475:16`) under [anchor]. Returns the new
/// period on Apply; `null` on Cancel, Escape or a click outside.
Future<DashboardPeriod?> showDashboardPeriodPicker(
  BuildContext context, {
  required Rect anchor,
  required DashboardPeriod period,
  required DateTime today,
}) => showGeneralDialog<DashboardPeriod>(
  context: context,
  barrierDismissible: true,
  barrierLabel: context.t(AdminTextKeys.periodDismiss),
  barrierColor: Colors.transparent,
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) {
    final window = MediaQuery.sizeOf(context);
    final wide = window.width >= _PeriodPicker.width + 32;
    final picker = _PeriodPicker(period: period, today: today, wide: wide);
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: anchor.bottom + 8,
            bottom: 16,
            right: wide ? window.width - anchor.right : 16,
            left: wide ? null : 16,
            child: Align(alignment: Alignment.topRight, child: SingleChildScrollView(child: picker)),
          ),
        ],
      ),
    );
  },
);

class _PeriodPicker extends StatefulWidget {
  const _PeriodPicker({required this.period, required this.today, required this.wide});

  final DashboardPeriod period;
  final DateTime today;

  /// Two months with the shortcuts beside them; else one month under them.
  final bool wide;

  static const width = 765.0;

  @override
  State<_PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends State<_PeriodPicker> {
  late DashboardPreset _preset = widget.period.preset;
  late DateTime _from = widget.period.from;
  late DateTime _to = widget.period.to;

  /// The month on the right (the only one when narrow).
  late DateTime _month = DateTime(_to.year, _to.month);

  /// Set by the first click on a day: the next click ends the period.
  bool _endingPeriod = false;
  bool _typedDateInvalid = false;
  final _fromField = TextEditingController();
  final _toField = TextEditingController();
  var _fieldsFilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fieldsFilled) {
      _fieldsFilled = true;
      _fillFields();
    }
  }

  @override
  void dispose() {
    _fromField.dispose();
    _toField.dispose();
    super.dispose();
  }

  void _fillFields() {
    _fromField.text = DashboardText.date(context, _from);
    _toField.text = DashboardText.date(context, _to);
    _typedDateInvalid = false;
  }

  DashboardPeriod get _draft => DashboardPeriod(_preset, _from, _to);

  void _pickPreset(DashboardPreset preset) => setState(() {
    _preset = preset;
    _endingPeriod = false;
    if (preset != DashboardPreset.custom) {
      final period = DashboardPeriod.of(preset, widget.today);
      _from = period.from;
      _to = period.to;
      _month = DateTime(_to.year, _to.month);
      _fillFields();
    }
  });

  void _pickDay(DateTime day) => setState(() {
    _preset = DashboardPreset.custom;
    if (!_endingPeriod) {
      _from = _to = day;
    } else if (day.isBefore(_from)) {
      _from = day;
    } else {
      _to = day;
    }
    _endingPeriod = !_endingPeriod;
    _fillFields();
  });

  void _typed() {
    final from = DashboardText.parseDate(context, _fromField.text);
    final to = DashboardText.parseDate(context, _toField.text);
    final valid = from != null && to != null && DashboardPeriod(DashboardPreset.custom, from, to).isValid(widget.today);
    setState(() {
      _typedDateInvalid = !valid;
      if (!valid) return;
      _preset = DashboardPreset.custom;
      _from = from;
      _to = to;
      _endingPeriod = false;
      _month = DateTime(to.year, to.month);
    });
  }

  void _moveMonth(int by) => setState(() => _month = DateTime(_month.year, _month.month + by));

  bool get _atThisMonth => _month.year == widget.today.year && _month.month == widget.today.month;

  /// While ending a period, days too far from its start can't be chosen.
  bool _selectable(DateTime day) =>
      !_endingPeriod || DashboardPeriod(DashboardPreset.custom, _from, day.isBefore(_from) ? _from : day).isValid(widget.today);

  Widget _shortcut(DashboardPreset preset, {required bool list}) {
    final selected = preset == _preset;
    return Material(
      color: selected ? JitanColors.inputFill : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pickPreset(preset),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: list ? 9 : 7),
          child: Text(
            context.t(preset.labelKey),
            style: JitanTextStyles.tableCell.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField(TextEditingController controller, String labelKey) => Semantics(
    label: context.t(labelKey),
    child: TextField(
      controller: controller,
      onChanged: (_) => _typed(),
      style: JitanTextStyles.tableCell,
      decoration: jitanFieldDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11)),
    ),
  );

  Widget _dateFields() => Row(
    children: [
      Flexible(child: SizedBox(width: 150, child: _dateField(_fromField, AdminTextKeys.periodFrom))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('–', style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
      ),
      Flexible(child: SizedBox(width: 150, child: _dateField(_toField, AdminTextKeys.periodTo))),
    ],
  );

  Widget _monthHeader(DateTime month, {required bool previous, required bool next}) {
    final title = Text(
      '${context.t(CommonTextKeys.monthLong[month.month - 1])} ${month.year}',
      textAlign: TextAlign.center,
      style: JitanTextStyles.tableCellStrong,
    );
    Widget arrow(IconData icon, String key, VoidCallback? onPressed) => IconButton(
      tooltip: context.t(key),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: JitanColors.ink,
      disabledColor: JitanColors.inputBorder,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
    );
    return Row(
      children: [
        previous ? arrow(Icons.chevron_left, AdminTextKeys.periodPreviousMonth, () => _moveMonth(-1)) : const SizedBox(width: 32),
        Expanded(child: title),
        next
            ? arrow(Icons.chevron_right, AdminTextKeys.periodNextMonth, _atThisMonth ? null : () => _moveMonth(1))
            : const SizedBox(width: 32),
      ],
    );
  }

  Widget _monthView(DateTime month, {required bool previous, required bool next}) => Column(
    spacing: 8,
    children: [
      _monthHeader(month, previous: previous, next: next),
      JitanMonthGrid(
        month: month,
        from: _from,
        to: _to,
        latest: widget.today,
        selectable: _selectable,
        onPick: _pickDay,
      ),
    ],
  );

  Widget _footer() => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: 10,
      children: [
        JitanSecondaryButton(
          label: context.t(AdminTextKeys.periodCancel),
          height: JitanDimensions.controlHeight,
          onPressed: () => Navigator.of(context).pop(),
        ),
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.periodApply),
          height: JitanDimensions.controlHeight,
          onPressed: _typedDateInvalid ? null : () => Navigator.of(context).pop(_draft),
        ),
      ],
    ),
  );

  Widget _wide() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 160,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final preset in DashboardPreset.values) _shortcut(preset, list: true)],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: JitanColors.inputBorder),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 14,
                  children: [
                    _dateFields(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 24,
                      children: [
                        Expanded(child: _monthView(DateTime(_month.year, _month.month - 1), previous: true, next: false)),
                        Expanded(child: _monthView(_month, previous: false, next: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: JitanColors.inputBorder),
      _footer(),
    ],
  );

  Widget _narrow() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [for (final preset in DashboardPreset.values) _shortcut(preset, list: false)],
            ),
            _dateFields(),
            _monthView(_month, previous: true, next: true),
          ],
        ),
      ),
      const Divider(height: 1, color: JitanColors.inputBorder),
      _footer(),
    ],
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.wide ? _PeriodPicker.width : double.infinity,
    child: Material(
      color: JitanColors.surface,
      elevation: 12,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(JitanDimensions.tableCardRadius),
      clipBehavior: Clip.antiAlias,
      child: widget.wide ? _wide() : _narrow(),
    ),
  );
}

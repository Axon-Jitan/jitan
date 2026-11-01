import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/web_services.dart';
import '../common/web_text.dart';
import '../l10n/employee_web_text_keys.dart';
import 'day_dialog.dart';
import 'day_status.dart';
import 'period_controller.dart';

/// Period (Figma `1499:478`, empty month `1501:192`, phone `1501:731`): a
/// month, reading like HR's Reports. A day opens in a window.
class PeriodScreen extends StatefulWidget {
  const PeriodScreen({super.key, required this.services, this.clock});

  final WebServices services;
  final DateTime Function()? clock;

  @override
  State<PeriodScreen> createState() => _PeriodScreenState();
}

class _PeriodScreenState extends State<PeriodScreen> {
  late final _controller = PeriodController(widget.services.times, clock: widget.clock)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(MyPeriodDay day) async {
    final changed = await showDayDialog(context, api: widget.services.times, day: day, clock: widget.clock);
    if (changed) await _controller.load();
  }

  Widget _month(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: context.t(EmployeeWebTextKeys.periodPrevious),
        icon: const Icon(Icons.chevron_left, size: 22, color: JitanColors.inkMuted),
        onPressed: () => _controller.go(-1),
      ),
      Text(WebText.month(context, _controller.month), style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 16)),
      IconButton(
        tooltip: context.t(EmployeeWebTextKeys.periodNext),
        icon: const Icon(Icons.chevron_right, size: 22, color: JitanColors.inkMuted),
        onPressed: _controller.canGoNext ? () => _controller.go(1) : null,
      ),
    ],
  );

  Widget _totals(BuildContext context, MyPeriod period) {
    final toFix = _controller.toFix;
    Widget total(String label, String value, {Color color = JitanColors.ink}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(label, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
        Text(value, style: JitanTextStyles.modalTitle.copyWith(fontSize: 26, color: color)),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Wrap(
        spacing: 64,
        runSpacing: 14,
        children: [
          total(context.t(EmployeeWebTextKeys.periodRegistered), WebText.duration(context, period.registeredMinutes)),
          total(context.t(EmployeeWebTextKeys.periodPlanned), WebText.duration(context, period.plannedMinutes)),
          total(
            context.t(EmployeeWebTextKeys.periodToFix),
            context.tPlural(EmployeeWebTextKeys.periodDays, toFix),
            color: toFix > 0 ? JitanColors.warning : JitanColors.ink,
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context) {
    final days = _controller.days;
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    if (days.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
          child: Text(context.t(EmployeeWebTextKeys.periodEmpty), style: JitanTextStyles.stateMessage),
        ),
      );
    }
    final t = TranslationScope.of(context);
    return JitanSliverTable(
      minWidth: phone ? 0 : 720,
      onRowTap: (i) => _open(days[i]),
      columns: [
        JitanTableColumn(label: t.t(EmployeeWebTextKeys.periodDay), flex: phone ? 150 : 300),
        if (!phone) ...[
          JitanTableColumn(label: t.t(EmployeeWebTextKeys.periodTime), flex: 300),
          JitanTableColumn(label: t.t(EmployeeWebTextKeys.periodRegistered), flex: 200),
        ],
        JitanTableColumn(label: t.t(EmployeeWebTextKeys.periodStatus), flex: phone ? 160 : 246),
        JitanTableColumn(label: '', flex: phone ? 30 : 30, align: JitanColumnAlign.end),
      ],
      rowCount: days.length,
      cells: (i) {
        final day = days[i];
        final status = DayStatus.of(day);
        final record = day.day;
        final start = record?.start?.roundedLocal ?? record?.start?.actualLocal;
        final finish = record?.finish?.roundedLocal ?? record?.finish?.actualLocal;
        return [
          Text(WebText.day(context, day.date), overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong),
          if (!phone) ...[
            Text('${start ?? '?'} – ${finish ?? '?'}', style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
            Text(
              day.registeredMinutes == null ? '—' : WebText.duration(context, day.registeredMinutes!),
              style: JitanTextStyles.tableCellStrong,
            ),
          ],
          phone && day.registeredMinutes != null
              ? Text(WebText.duration(context, day.registeredMinutes!), style: JitanTextStyles.tableCell)
              : DayStatusLabel(status: status),
          const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (_controller.failed) return WebNoConnection(onRetry: _controller.load);
      final period = _controller.period;
      return JitanListPage(
        top: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JitanPageHeader(
              title: context.t(EmployeeWebTextKeys.periodTitle),
              subtitle: context.t(EmployeeWebTextKeys.periodSubtitle),
            ),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft, child: _month(context)),
            const SizedBox(height: 12),
            if (period != null) _totals(context, period),
            const SizedBox(height: 20),
          ],
        ),
        list: [
          period == null
              ? SliverToBoxAdapter(child: JitanLoadingState(label: context.t(EmployeeWebTextKeys.loading)))
              : _table(context),
        ],
      );
    },
  );
}

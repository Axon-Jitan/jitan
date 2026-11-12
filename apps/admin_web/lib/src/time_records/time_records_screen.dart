import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'time_correction_flow.dart';
import 'time_record_dialog.dart';
import 'time_record_text.dart';
import '../period/period_text.dart';
import 'time_record_status_filter.dart';
import 'time_records_controller.dart';
import 'time_records_days.dart';

/// HR/Admin "Time records" (Figma `HR / Time records V2 — page` `1565:2`):
/// every employee's days in a period, grouped by day, with the period at the
/// top right, a search and the Company and Show filters, and a day's pop-up
/// (`1566:2`) and its corrections (`1566:272`, `1566:788`, `1566:1040`).
class TimeRecordsScreen extends StatefulWidget {
  const TimeRecordsScreen({super.key, required this.api, required this.companiesApi, this.today, this.status, this.range});

  final TimeRecordsApi api;
  final CompaniesApi companiesApi;

  /// "Today" for the period filter; the device's date when `null`.
  final DateTime Function()? today;

  /// Opened from the Dashboard: what to show at first.
  final TimeRecordStatusFilter? status;
  final ({DateTime from, DateTime to})? range;

  @override
  State<TimeRecordsScreen> createState() => _TimeRecordsScreenState();
}

class _TimeRecordsScreenState extends State<TimeRecordsScreen> {
  late final _controller = TimeRecordsController(widget.api, today: widget.today, status: widget.status, range: widget.range)..load();
  final _search = TextEditingController();
  List<CompanySummary>? _companies;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await widget.companiesApi.listCompanies();
      if (mounted) setState(() => _companies = companies);
    } on ApiClientException {
      // The company filter stays on "All companies"; the list still loads.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  void _resetAll() {
    _search.clear();
    _controller.resetAll();
  }

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanPageHeader(
            title: context.t(AdminTextKeys.timeRecordsTitle),
            subtitle: _subtitle(context),
            action: _period(context),
          ),
          const SizedBox(height: JitanDimensions.headerToToolbar),
          _toolbar(context),
          const SizedBox(height: JitanDimensions.toolbarToTable),
        ],
      ),
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  /// "This week · 9 – 15 Nov 2026 · 24 days to review".
  String _subtitle(BuildContext context) {
    final (from, to) = _controller.dates;
    final period = _controller.period;
    final toReview = _controller.toReviewCount;
    return [
      if (period != null) TimeRecordText.period(context, period),
      PeriodText.range(context, from, to),
      if (toReview > 0) context.tPlural(AdminTextKeys.timeRecordsToReviewDays, toReview),
    ].join(' · ');
  }

  /// This week, last week, this month, last month; the exact days a
  /// Dashboard link opened until another is chosen.
  Widget _period(BuildContext context) {
    final range = _controller.range;
    final (from, to) = _controller.dates;
    return JitanFilterSelect<TimeRecordPeriod?>(
      value: _controller.period,
      detail: _controller.period == null ? null : PeriodText.range(context, from, to),
      alignEnd: true,
      options: [
        if (range != null) JitanSelectOption(value: null, label: PeriodText.range(context, range.from, range.to)),
        for (final p in TimeRecordPeriod.values) JitanSelectOption(value: p, label: TimeRecordText.period(context, p)),
      ],
      onChanged: (p) {
        if (p != null) _controller.selectPeriod(p);
      },
    );
  }

  Widget _toolbar(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final phone = constraints.maxWidth < JitanDimensions.phoneBreakpoint;
      final search = JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        controller: _search,
        hintText: context.t(AdminTextKeys.timeRecordsFilterEmployeeHint),
        onChanged: _controller.updateSearch,
      );
      final company = JitanFilterSelect<int?>(
        label: context.t(AdminTextKeys.timeRecordsFilterCompany),
        value: _controller.companyId,
        expanded: phone,
        options: [
          JitanSelectOption(value: null, label: context.t(AdminTextKeys.employeeFilterCompanyAll)),
          for (final c in _companies ?? const <CompanySummary>[]) JitanSelectOption(value: c.id, label: c.name),
        ],
        onChanged: _controller.selectCompany,
      );
      final show = JitanFilterSelect<TimeRecordStatusFilter?>(
        label: context.t(AdminTextKeys.timeRecordsFilterShow),
        value: _controller.status,
        expanded: phone,
        options: [
          JitanSelectOption(value: null, label: context.t(AdminTextKeys.timeRecordsStatusAll)),
          JitanSelectOption(value: TimeRecordStatusFilter.toReview, label: context.t(AdminTextKeys.timeRecordsStatusToReview)),
          JitanSelectOption(value: TimeRecordStatusFilter.finished, label: context.t(AdminTextKeys.timeRecordsStatusFinished)),
          for (final (attendance, key) in [
            (DayAttendance.onTime, AdminTextKeys.timeRecordsAttendanceOnTime),
            (DayAttendance.late, AdminTextKeys.timeRecordsAttendanceLate),
            (DayAttendance.leftEarly, AdminTextKeys.timeRecordsAttendanceLeftEarly),
          ])
            JitanSelectOption(value: TimeRecordStatusFilter.attended(attendance), label: context.t(key)),
          for (final s in TimeRecordStatus.values)
            JitanSelectOption(value: TimeRecordStatusFilter.only(s), label: TimeRecordText.status(context, s)),
        ],
        onChanged: _controller.selectStatus,
      );
      // Only while something is filtered.
      final clear = _controller.isFiltered
          ? TextButton(
              onPressed: _resetAll,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 40)),
              child: Text(
                context.t(AdminTextKeys.timeRecordsResetAll),
                style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.vermilion),
              ),
            )
          : null;
      if (phone) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [search, company, show, if (clear != null) Align(alignment: Alignment.centerLeft, child: clear)],
        );
      }
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [SizedBox(width: 320, child: search), company, show, ?clear],
      );
    },
  );

  Widget _content(BuildContext context) => switch (_controller.state) {
    TimeRecordsLoading() => _line(GroupStateText(context.t(AdminTextKeys.timeRecordsLoading))),
    TimeRecordsFailed() => _line(GroupStateText(context.t(AdminTextKeys.timeRecordsLoadFailed), onRetry: _controller.load)),
    TimeRecordsLoaded() when _controller.loadedCount == 0 && !_controller.isFiltered => SliverToBoxAdapter(
      child: JitanNoResults(
        title: context.t(AdminTextKeys.timeRecordsEmptyTitle),
        message: context.t(AdminTextKeys.timeRecordsEmptyMessage),
      ),
    ),
    TimeRecordsLoaded() => switch (_controller.visibleDays) {
      [] => SliverToBoxAdapter(
        child: JitanNoResults(
          title: context.t(AdminTextKeys.timeRecordsNoMatchTitle),
          message: context.t(AdminTextKeys.timeRecordsNoMatchMessage),
        ),
      ),
      final days => TimeRecordsDays(
        days: days,
        today: _controller.today,
        actionOf: (day) => _companyOf(day) == null ? null : TimeCorrectionStep.forRow(day),
        onOpen: _open,
      ),
    },
  };

  static Widget _line(Widget child) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 4), child: child));

  /// The company a correction of [day] is made in: the filter's, else the
  /// employee's first. The server checks the right there (§28a.5).
  int? _companyOf(TimeRecordDay day) {
    final filter = _controller.companyId;
    return filter != null && day.companyIds.contains(filter) ? filter : day.companyIds.firstOrNull;
  }

  /// A row: straight to Fix or Review when there is one, else the day.
  Future<void> _open(TimeRecordDay day) async {
    final mayCorrect = _companyOf(day) != null;
    final step = (mayCorrect ? TimeCorrectionStep.forRow(day) : null) ??
        await showTimeRecordDialog(context, day: day, mayCorrect: mayCorrect);
    if (step != null && mounted) await _correct(day, step);
  }

  Future<void> _correct(TimeRecordDay day, TimeCorrectionStep step) async {
    final companyId = _companyOf(day);
    if (companyId == null) return;
    final saved = await showTimeCorrection(context, api: widget.api, day: day, companyId: companyId, step: step);
    if (saved && mounted) await _controller.load();
  }
}

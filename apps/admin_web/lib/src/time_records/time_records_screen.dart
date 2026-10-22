import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'time_correction_flow.dart';
import 'time_record_dialog.dart';
import 'time_record_text.dart';
import 'time_records_controller.dart';
import 'time_records_table.dart';

/// HR/Admin "Time records" (Figma `HR / Time records` 160:2): every
/// employee's working days in a period, with filters for company, employee,
/// period and status, and the day detail (160:94).
class TimeRecordsScreen extends StatefulWidget {
  const TimeRecordsScreen({super.key, required this.api, required this.companiesApi, this.today});

  final TimeRecordsApi api;
  final CompaniesApi companiesApi;

  /// "Today" for the period filter; the device's date when `null`.
  final DateTime Function()? today;

  @override
  State<TimeRecordsScreen> createState() => _TimeRecordsScreenState();
}

class _TimeRecordsScreenState extends State<TimeRecordsScreen> {
  late final _controller = TimeRecordsController(widget.api, today: widget.today)..load();
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
            subtitle: context.t(AdminTextKeys.timeRecordsSubtitle),
          ),
          const SizedBox(height: JitanDimensions.headerToToolbar),
          _toolbar(context),
          const SizedBox(height: 28),
          Text(context.t(AdminTextKeys.timeRecordsSection), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
        ],
      ),
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  Widget _toolbar(BuildContext context) {
    final company = JitanSelectField<int?>(
      label: context.t(AdminTextKeys.timeRecordsFilterCompany),
      value: _controller.companyId,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.employeeFilterCompanyAll)),
        for (final c in _companies ?? const <CompanySummary>[]) JitanSelectOption(value: c.id, label: c.name),
      ],
      onChanged: _controller.selectCompany,
    );
    final employee = JitanFieldLabel(
      label: context.t(AdminTextKeys.timeRecordsFilterEmployee),
      child: JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        controller: _search,
        hintText: context.t(AdminTextKeys.timeRecordsFilterEmployeeHint),
        onChanged: _controller.updateSearch,
      ),
    );
    final period = JitanSelectField<TimeRecordPeriod>(
      label: context.t(AdminTextKeys.timeRecordsFilterPeriod),
      value: _controller.period,
      options: [
        for (final p in TimeRecordPeriod.values) JitanSelectOption(value: p, label: TimeRecordText.period(context, p)),
      ],
      onChanged: (p) => _controller.selectPeriod(p ?? TimeRecordPeriod.thisWeek),
    );
    final status = JitanSelectField<TimeRecordStatus?>(
      label: context.t(AdminTextKeys.timeRecordsFilterStatus),
      value: _controller.status,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.timeRecordsStatusAll)),
        for (final s in TimeRecordStatus.values) JitanSelectOption(value: s, label: TimeRecordText.status(context, s)),
      ],
      onChanged: _controller.selectStatus,
    );
    final reset = TextButton(
      onPressed: _controller.isFiltered ? _resetAll : null,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 44)),
      child: Text(
        context.t(AdminTextKeys.timeRecordsResetAll),
        style: JitanTextStyles.tableCellStrong.copyWith(
          color: _controller.isFiltered ? JitanColors.vermilion : JitanColors.disabledText,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 900
          ? Wrap(
              spacing: 16,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                for (final field in [company, employee, period, status])
                  SizedBox(
                    width: constraints.maxWidth < JitanDimensions.phoneBreakpoint
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 16) / 2,
                    child: field,
                  ),
                reset,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 160, child: company),
                const SizedBox(width: 16),
                Expanded(flex: 180, child: employee),
                const SizedBox(width: 16),
                Expanded(flex: 150, child: period),
                const SizedBox(width: 16),
                Expanded(flex: 160, child: status),
                const SizedBox(width: 24),
                reset,
              ],
            ),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    TimeRecordsLoading() => JitanTableStateSliver(child: JitanLoadingState(label: context.t(AdminTextKeys.timeRecordsLoading))),
    TimeRecordsFailed(:final failure) => JitanTableStateSliver(child: _error(context, failure)),
    TimeRecordsLoaded() when _controller.loadedCount == 0 && !_controller.isFiltered => JitanTableStateSliver(
      child: JitanEmptyState(
        title: context.t(AdminTextKeys.timeRecordsEmptyTitle),
        message: context.t(AdminTextKeys.timeRecordsEmptyMessage),
      ),
    ),
    TimeRecordsLoaded() => switch (_controller.visibleDays) {
      [] => JitanTableStateSliver(
        child: JitanEmptyState(
          title: context.t(AdminTextKeys.timeRecordsNoMatchTitle),
          message: context.t(AdminTextKeys.timeRecordsNoMatchMessage),
        ),
      ),
      final days => TimeRecordsTable(
        days: days,
        onView: _view,
        onCorrect: _correct,
        mayCorrect: (day) => _companyOf(day) != null,
      ),
    },
  };

  /// The company a correction of [day] is made in: the filter's, else the
  /// employee's first. The server checks the right there (§28a.5).
  int? _companyOf(TimeRecordDay day) {
    final filter = _controller.companyId;
    return filter != null && day.companyIds.contains(filter) ? filter : day.companyIds.firstOrNull;
  }

  Future<void> _view(TimeRecordDay day) async {
    final step = await showTimeRecordDialog(context, day: day, mayCorrect: _companyOf(day) != null);
    if (step != null && mounted) await _correct(day, step);
  }

  Future<void> _correct(TimeRecordDay day, TimeCorrectionStep step) async {
    final companyId = _companyOf(day);
    if (companyId == null) return;
    final saved = await showTimeCorrection(context, api: widget.api, day: day, companyId: companyId, step: step);
    if (saved && mounted) await _controller.load();
  }

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanErrorState(
      title: context.t(keys.title),
      message: context.t(keys.message),
      retryLabel: context.t(CommonTextKeys.retry),
      onRetry: _controller.load,
    );
  }
}

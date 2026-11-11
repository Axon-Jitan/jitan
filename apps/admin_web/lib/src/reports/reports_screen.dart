import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../employees/import/platform/file_download.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import '../period/chosen_period.dart';
import '../period/period_button.dart';
import 'project_reports_controller.dart';
import 'project_reports_view.dart';
import 'report_employee_dialog.dart';
import 'report_export.dart';
import 'report_totals_card.dart';
import 'report_view_switch.dart';
import 'reports_controller.dart';
import 'reports_table.dart';

/// HR/Admin "Reports" (Figma `1467:2`, export `1467:230`, empty `1467:631`):
/// one month, per employee, with only what Jitan can calculate. The page is
/// its own preview. "Employees | Projects" switches to the project report
/// (Figma `1515:2`, D24).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.api,
    required this.companiesApi,
    this.store,
    this.today,
    this.download = downloadFile,
  });

  final ReportsApi api;
  final CompaniesApi companiesApi;

  /// Where the chosen period is remembered; nowhere when `null`.
  final SessionStore? store;

  /// `DateTime.now` when `null`.
  final DateTime Function()? today;
  final DownloadFile download;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final _now = (widget.today ?? DateTime.now)();
  late final _controller = ReportsController(widget.api, widget.store ?? MemorySessionStore(), today: _now)..load();
  ProjectReportsController? _projects;
  ReportView _view = ReportView.employees;
  final _menu = MenuController();
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
      // The company filter stays on "All companies"; the report still loads.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _projects?.dispose();
    super.dispose();
  }

  /// The project report loads the first time it is shown, for the month the
  /// employees' report is on.
  void _show(ReportView view) => setState(() {
    _view = view;
    if (view == ReportView.projects && _projects == null) {
      _projects = ProjectReportsController(widget.api, period: _controller.period)..load();
    }
  });

  Widget _switch() => ReportViewSwitch(value: _view, onChanged: _show);

  /// One period for both views, remembered in this browser.
  void _changePeriod(ChosenPeriod period) {
    _controller.updatePeriod(period);
    _projects?.updatePeriod(period);
  }

  List<String> _titles() => [
    for (final key in [
      AdminTextKeys.reportFileCode,
      AdminTextKeys.reportFileFirstName,
      AdminTextKeys.reportFileLastName,
      AdminTextKeys.reportFilePlanned,
      AdminTextKeys.reportFileRegistered,
      AdminTextKeys.reportFileDifference,
      AdminTextKeys.reportFileTravel,
      AdminTextKeys.reportFileToReview,
      AdminTextKeys.reportFileTrips,
      AdminTextKeys.reportFileKilometres,
      AdminTextKeys.reportFileUnknownTrips,
    ])
      context.t(key),
  ];

  void _exportExcel() => widget.download(
    ReportExport.fileName(_controller.period.from, _controller.period.to, 'xlsx'),
    ReportExport.excel(_titles(), _controller.visible),
    ReportExport.excelType,
  );

  void _exportCsv() => widget.download(
    ReportExport.fileName(_controller.period.from, _controller.period.to, 'csv'),
    ReportExport.csv(_titles(), _controller.visible),
    ReportExport.csvType,
  );

  bool get _empty => switch (_controller.state) {
    ReportsLoaded(:final report) => report.employees.isEmpty,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => _view == ReportView.projects
      ? ProjectReportsView(
          controller: _projects!,
          today: _now,
          onPeriodChanged: _changePeriod,
          viewSwitch: _switch(),
          download: widget.download,
        )
      : _employees(context);

  Widget _employees(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final loaded = _controller.state is ReportsLoaded && _controller.visible.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JitanPageHeader(
              title: context.t(AdminTextKeys.reportTitle),
              subtitle: context.t(AdminTextKeys.reportSubtitle),
              action: MenuAnchor(
                controller: _menu,
                alignmentOffset: const Offset(0, 6),
                menuChildren: [
                  MenuItemButton(onPressed: _exportExcel, child: Text(context.t(AdminTextKeys.reportExportExcel))),
                  MenuItemButton(onPressed: _exportCsv, child: Text(context.t(AdminTextKeys.reportExportCsv))),
                ],
                child: JitanPrimaryButton(
                  label: context.t(AdminTextKeys.reportExport),
                  height: JitanDimensions.controlHeight,
                  onPressed: loaded ? () => _menu.isOpen ? _menu.close() : _menu.open() : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _switch(),
            const SizedBox(height: 24),
            _toolbar(context),
            const SizedBox(height: JitanDimensions.toolbarToTable),
            if (loaded) ...[ReportTotalsCard(employees: _controller.visible), const SizedBox(height: 16)],
          ],
        );
      },
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  Widget _toolbar(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    final period = JitanFieldLabel(
      label: context.t(AdminTextKeys.reportPeriod),
      child: PeriodButton(period: _controller.period, today: _now, onChanged: _changePeriod, expanded: phone),
    );
    final company = JitanSelectField<int?>(
      label: context.t(AdminTextKeys.reportCompany),
      value: _controller.companyId,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.reportCompanyAll)),
        for (final c in _companies ?? const <CompanySummary>[]) JitanSelectOption(value: c.id, label: c.name),
      ],
      onChanged: _controller.updateCompany,
    );
    final search = JitanFieldLabel(
      label: context.t(CommonTextKeys.searchLabel),
      child: JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        hintText: context.t(AdminTextKeys.reportSearch),
        onChanged: _controller.updateSearch,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [period, company, search],
            )
          : Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                period,
                SizedBox(width: 220, child: company),
                SizedBox(width: 300, child: search),
              ],
            ),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    ReportsLoading() => _state(GroupStateText(context.t(AdminTextKeys.reportLoading))),
    ReportsFailed() => _state(GroupStateText(context.t(AdminTextKeys.reportLoadFailed), onRetry: _controller.load)),
    ReportsLoaded() when _empty => SliverToBoxAdapter(child: _emptyMonth(context)),
    ReportsLoaded() => switch (_controller.visible) {
      [] => _state(GroupStateText(context.t(AdminTextKeys.reportNoMatch))),
      final employees => ReportsTable(
        employees: employees,
        onOpen: (employee) => showReportEmployeeDialog(context, employee: employee, period: _controller.period),
      ),
    },
  };

  Widget _emptyMonth(BuildContext context) => JitanSurfaceCard(
    radius: JitanDimensions.tableCardRadius,
    child: SizedBox(
      height: 420,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.t(AdminTextKeys.reportEmptyTitle),
              textAlign: TextAlign.center,
              style: JitanTextStyles.modalTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              context.t(AdminTextKeys.reportEmptyText),
              textAlign: TextAlign.center,
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
          ],
        ),
      ),
    ),
  );

  static Widget _state(Widget child) => SliverToBoxAdapter(
    child: Padding(padding: const EdgeInsets.only(top: 20), child: child),
  );
}

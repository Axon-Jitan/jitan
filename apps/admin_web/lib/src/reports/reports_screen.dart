import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../employees/import/platform/file_download.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import '../period/chosen_period.dart';
import '../period/period_button.dart';
import 'project_reports_controller.dart';
import 'project_reports_view.dart';
import 'report_employee_dialog.dart';
import 'report_export.dart';
import 'report_export_button.dart';
import 'report_totals_card.dart';
import 'report_view_switch.dart';
import 'reports_controller.dart';
import 'reports_layout.dart';
import 'reports_table.dart';
import '../time_records/time_record_status_filter.dart';

/// HR/Admin "Reports" (Figma `HR / Reports V2 — employees` `1571:2`, export
/// `1572:2`, an employee `1572:240`, empty `1467:631`): one period, per
/// employee, with only what Jitan can calculate. The page is its own preview.
/// The period and Export sit at the top right; "Employees | Projects" starts
/// the toolbar and switches to the project report (`1571:390`, D24). Days to
/// review open in Time records.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.api,
    required this.companiesApi,
    this.store,
    this.today,
    this.download = downloadFile,
    this.navigate,
  });

  final ReportsApi api;
  final CompaniesApi companiesApi;

  /// Where the chosen period is remembered; nowhere when `null`.
  final SessionStore? store;

  /// `DateTime.now` when `null`.
  final DateTime Function()? today;
  final DownloadFile download;

  /// Goes to another page; the router's when `null`.
  final ValueChanged<String>? navigate;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final _now = (widget.today ?? DateTime.now)();
  late final _controller = ReportsController(widget.api, widget.store ?? MemorySessionStore(), today: _now)..load();
  ProjectReportsController? _projects;
  ReportView _view = ReportView.employees;
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

  /// The period's days to review, in Time records.
  void _openReview() {
    final period = _controller.period;
    final location = AdminRoutes.timeRecordsOf(status: TimeRecordStatusFilter.toReview.wireName, from: period.from, to: period.to);
    (widget.navigate ?? context.go)(location);
  }

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
              action: reportHeaderActions(
                PeriodButton(period: _controller.period, today: _now, expanded: _phone(context), onChanged: _changePeriod),
                ReportExportButton(onExcel: _exportExcel, onCsv: _exportCsv, enabled: loaded),
                phone: _phone(context),
              ),
            ),
            const SizedBox(height: JitanDimensions.headerToToolbar),
            _toolbar(context),
            const SizedBox(height: JitanDimensions.toolbarToTable),
            if (loaded) ...[
              ReportTotalsCard(employees: _controller.visible, onReview: _openReview),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  /// Employees | Projects, the search and the company (Figma `1571:2`).
  Widget _toolbar(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final phone = constraints.maxWidth < JitanDimensions.phoneBreakpoint;
      final search = JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        hintText: context.t(AdminTextKeys.reportSearch),
        onChanged: _controller.updateSearch,
      );
      final company = JitanFilterSelect<int?>(
        label: context.t(AdminTextKeys.reportCompany),
        value: _controller.companyId,
        expanded: phone,
        options: [
          JitanSelectOption(value: null, label: context.t(AdminTextKeys.reportCompanyAll)),
          for (final c in _companies ?? const <CompanySummary>[]) JitanSelectOption(value: c.id, label: c.name),
        ],
        onChanged: _controller.updateCompany,
      );
      return reportToolbar(phone: phone, viewSwitch: _switch(), search: search, filters: [company]);
    },
  );

  Widget _content(BuildContext context) => switch (_controller.state) {
    ReportsLoading() => _state(GroupStateText(context.t(AdminTextKeys.reportLoading))),
    ReportsFailed() => _state(GroupStateText(context.t(AdminTextKeys.reportLoadFailed), onRetry: _controller.load)),
    ReportsLoaded() when _empty => SliverToBoxAdapter(
      child: JitanNoResults(title: context.t(AdminTextKeys.reportEmptyTitle), message: context.t(AdminTextKeys.reportEmptyText)),
    ),
    ReportsLoaded() => switch (_controller.visible) {
      [] => SliverToBoxAdapter(
        child: JitanNoResults(title: context.t(AdminTextKeys.reportNoMatch), message: context.t(AdminTextKeys.reportNoMatchText)),
      ),
      final employees => SliverMainAxisGroup(
        slivers: [
          ReportsTable(
            employees: employees,
            onOpen: (employee) => showReportEmployeeDialog(context, employee: employee, period: _controller.period),
          ),
          reportNote([
            context.tPlural(AdminTextKeys.reportEmployees, employees.length),
            if (employees.any((e) => e.tripsWithoutDistance > 0)) context.t(AdminTextKeys.reportUnknownDistance),
          ]),
        ],
      ),
    },
  };

  static bool _phone(BuildContext context) => MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;

  static Widget _state(Widget child) => SliverToBoxAdapter(
    child: Padding(padding: const EdgeInsets.only(top: 20), child: child),
  );
}

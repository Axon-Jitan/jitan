import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../employees/import/platform/file_download.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'report_employee_dialog.dart';
import 'report_export.dart';
import 'report_text.dart';
import 'report_totals_card.dart';
import 'reports_controller.dart';
import 'reports_table.dart';

/// HR/Admin "Reports" (Figma `1467:2`, export `1467:230`, empty `1467:631`):
/// one month, per employee, with only what Jitan can calculate. The page is
/// its own preview.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.api,
    required this.companiesApi,
    this.today,
    this.download = downloadFile,
  });

  final ReportsApi api;
  final CompaniesApi companiesApi;

  /// `DateTime.now` when `null`.
  final DateTime Function()? today;
  final DownloadFile download;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final _now = (widget.today ?? DateTime.now)();
  late final _months = ReportText.recentMonths(_now);
  late final _controller = ReportsController(widget.api, month: _months.first)..load();
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
    super.dispose();
  }

  List<String> _titles() => [
    for (final key in [
      AdminTextKeys.reportFileCode,
      AdminTextKeys.reportFileFirstName,
      AdminTextKeys.reportFileLastName,
      AdminTextKeys.reportFilePlanned,
      AdminTextKeys.reportFileRegistered,
      AdminTextKeys.reportFileDifference,
      AdminTextKeys.reportFileToReview,
    ])
      context.t(key),
  ];

  void _exportExcel() => widget.download(
    ReportExport.fileName(_controller.month, 'xlsx'),
    ReportExport.excel(_titles(), _controller.visible),
    ReportExport.excelType,
  );

  void _exportCsv() => widget.download(
    ReportExport.fileName(_controller.month, 'csv'),
    ReportExport.csv(_titles(), _controller.visible),
    ReportExport.csvType,
  );

  bool get _empty => switch (_controller.state) {
    ReportsLoaded(:final report) => report.employees.isEmpty,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => JitanListPage(
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
            const SizedBox(height: JitanDimensions.headerToToolbar),
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
    final month = JitanSelectField<String>(
      label: context.t(AdminTextKeys.reportMonth),
      value: _controller.month,
      options: [for (final m in _months) JitanSelectOption(value: m, label: ReportText.month(context, m))],
      onChanged: (m) {
        if (m != null) _controller.updateMonth(m);
      },
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
              children: [month, company, search],
            )
          : Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(width: 200, child: month),
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
        onOpen: (employee) => showReportEmployeeDialog(context, employee: employee, month: _controller.month),
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

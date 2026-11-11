import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../employees/import/platform/file_download.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import '../period/chosen_period.dart';
import '../period/period_button.dart';
import 'project_report_dialog.dart';
import 'project_reports_controller.dart';
import 'project_reports_table.dart';
import 'report_export.dart';
import 'report_numbers_card.dart';
import 'report_text.dart';

/// Reports, Projects (Figma `1515:2`, a project `1515:190`, D24): one period,
/// per project, with only what Jitan records. A project has no company (D44),
/// so there is no company filter.
class ProjectReportsView extends StatefulWidget {
  const ProjectReportsView({
    super.key,
    required this.controller,
    required this.today,
    required this.onPeriodChanged,
    required this.viewSwitch,
    required this.download,
  });

  final ProjectReportsController controller;

  final DateTime today;

  /// The period is the page's, shared with the employees' report.
  final ValueChanged<ChosenPeriod> onPeriodChanged;
  final Widget viewSwitch;
  final DownloadFile download;

  @override
  State<ProjectReportsView> createState() => _ProjectReportsViewState();
}

class _ProjectReportsViewState extends State<ProjectReportsView> {
  final _menu = MenuController();

  ProjectReportsController get _controller => widget.controller;

  List<String> _titles() => [
    for (final key in [
      AdminTextKeys.reportFileSapNumber,
      AdminTextKeys.reportFileProject,
      AdminTextKeys.reportFilePlace,
      AdminTextKeys.reportFileEmployees,
      AdminTextKeys.reportFileRegistered,
      AdminTextKeys.reportFileTravel,
      AdminTextKeys.reportFileTrips,
      AdminTextKeys.reportFileKilometres,
      AdminTextKeys.reportFileUnknownTrips,
    ])
      context.t(key),
  ];

  void _export(String extension) {
    final rows = [for (final p in _controller.visible) ReportExport.projectRow(p)];
    final excel = extension == 'xlsx';
    widget.download(
      ReportExport.projectFileName(_controller.period.from, _controller.period.to, extension),
      excel ? ReportExport.excelOf(_titles(), rows) : ReportExport.csvOf(_titles(), rows),
      excel ? ReportExport.excelType : ReportExport.csvType,
    );
  }

  bool get _empty => switch (_controller.state) {
    ProjectReportsLoaded(:final report) => report.projects.isEmpty,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final loaded = _controller.state is ProjectReportsLoaded && _controller.visible.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JitanPageHeader(
              title: context.t(AdminTextKeys.reportTitle),
              subtitle: context.t(AdminTextKeys.reportProjectsSubtitle),
              action: MenuAnchor(
                controller: _menu,
                alignmentOffset: const Offset(0, 6),
                menuChildren: [
                  MenuItemButton(onPressed: () => _export('xlsx'), child: Text(context.t(AdminTextKeys.reportExportExcel))),
                  MenuItemButton(onPressed: () => _export('csv'), child: Text(context.t(AdminTextKeys.reportExportCsv))),
                ],
                child: JitanPrimaryButton(
                  label: context.t(AdminTextKeys.reportExport),
                  height: JitanDimensions.controlHeight,
                  onPressed: loaded ? () => _menu.isOpen ? _menu.close() : _menu.open() : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            widget.viewSwitch,
            const SizedBox(height: 24),
            _toolbar(context),
            const SizedBox(height: JitanDimensions.toolbarToTable),
            if (loaded) ...[_totals(context), const SizedBox(height: 16)],
          ],
        );
      },
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  Widget _totals(BuildContext context) {
    final projects = _controller.visible;
    int sum(int Function(ProjectReportProject) of) => projects.fold(0, (total, p) => total + of(p));
    final trips = sum((p) => p.trips), metres = sum((p) => p.distanceMetres), unknown = sum((p) => p.tripsWithoutDistance);
    return ReportNumbersCard(
      numbers: [
        (context.t(AdminTextKeys.reportTotalProjects), '${projects.length}', JitanColors.ink),
        (context.t(AdminTextKeys.reportRegistered), ReportText.hours(context, sum((p) => p.workedMinutes)), JitanColors.ink),
        (context.t(AdminTextKeys.reportTravel), ReportText.hours(context, sum((p) => p.travelMinutes)), JitanColors.ink),
        (
          context.t(AdminTextKeys.reportColumnKilometres),
          ReportText.distance(context, trips, metres),
          unknown > 0 ? JitanColors.warning : JitanColors.ink,
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    final period = JitanFieldLabel(
      label: context.t(AdminTextKeys.reportPeriod),
      child: PeriodButton(period: _controller.period, today: widget.today, onChanged: widget.onPeriodChanged, expanded: phone),
    );
    final search = JitanFieldLabel(
      label: context.t(CommonTextKeys.searchLabel),
      child: JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        hintText: context.t(AdminTextKeys.reportProjectsSearch),
        onChanged: _controller.updateSearch,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [period, search])
          : Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [period, SizedBox(width: 300, child: search)],
            ),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    ProjectReportsLoading() => _state(GroupStateText(context.t(AdminTextKeys.reportLoading))),
    ProjectReportsFailed() => _state(GroupStateText(context.t(AdminTextKeys.reportLoadFailed), onRetry: _controller.load)),
    ProjectReportsLoaded() when _empty => SliverToBoxAdapter(child: _emptyMonth(context)),
    ProjectReportsLoaded() => switch (_controller.visible) {
      [] => _state(GroupStateText(context.t(AdminTextKeys.reportProjectsNoMatch))),
      final projects => ProjectReportsTable(
        projects: projects,
        onOpen: (project) => showProjectReportDialog(context, project: project, period: _controller.period),
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
              context.t(AdminTextKeys.reportProjectsEmptyTitle),
              textAlign: TextAlign.center,
              style: JitanTextStyles.modalTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              context.t(AdminTextKeys.reportProjectsEmptyText),
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

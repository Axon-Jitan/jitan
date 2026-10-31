import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'assign_employees_dialog.dart';
import 'manage_project_dialog.dart';
import 'project_dialog.dart';
import 'projects_controller.dart';
import 'projects_table.dart';

/// HR/Admin "Projects" (Figma `647:1192`): every project the viewer may see.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.api,
    required this.companiesApi,
    required this.employeesApi,
    required this.locationsApi,
  });

  final ProjectsApi api;
  final CompaniesApi companiesApi;
  final EmployeesApi employeesApi;
  final LocationsApi locationsApi;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final _controller = ProjectsController(widget.api)..load();
  List<ProjectChoice> _statuses = const [];

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    try {
      final options = await widget.api.options();
      if (mounted) setState(() => _statuses = options.statuses);
    } on ApiClientException {
      // The status filter stays on "All statuses"; the list still loads.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<ProjectDetails?> _edit([ProjectDetails? project]) => showProjectDialog(
    context,
    api: widget.api,
    companiesApi: widget.companiesApi,
    locationsApi: widget.locationsApi,
    project: project,
  );

  Future<ProjectDetails?> _assign(ProjectDetails project) =>
      showAssignEmployeesDialog(context, api: widget.api, employeesApi: widget.employeesApi, project: project);

  /// "Create & assign": the team is chosen right after the project is saved.
  Future<void> _add() async {
    final created = await _edit();
    if (created == null || !mounted) return;
    await _controller.load();
    if (!mounted) return;
    _say(context.t(AdminTextKeys.projectAdded, args: {'project': created.summary.name}));
    await _assign(created);
    await _controller.load();
  }

  void _open(ProjectSummary project) => context.go(AdminRoutes.project(project.companyId, project.id));

  Future<void> _manage(ProjectSummary project) async {
    final action = await showManageProjectDialog(context, project: project);
    if (action == null || !mounted) return;
    if (action == ProjectAction.view) return _open(project);
    try {
      final details = await widget.api.find(project.companyId, project.id);
      if (!mounted) return;
      await (action == ProjectAction.edit ? _edit(details) : _assign(details));
      await _controller.load();
    } on ApiClientException {
      await _controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanPageHeader(
            title: context.t(AdminTextKeys.projectsTitle),
            subtitle: context.t(AdminTextKeys.projectsSubtitle),
            action: JitanPrimaryButton(
              label: context.t(AdminTextKeys.projectAdd),
              height: JitanDimensions.controlHeight,
              onPressed: _add,
            ),
          ),
          const SizedBox(height: JitanDimensions.headerToToolbar),
          _toolbar(context),
          const SizedBox(height: JitanDimensions.toolbarToTable),
        ],
      ),
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  Widget _toolbar(BuildContext context) {
    final seen = <int, String>{for (final p in _controller.all) p.companyId: p.companyName};
    final search = JitanFieldLabel(
      label: context.t(CommonTextKeys.searchLabel),
      child: JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        hintText: context.t(AdminTextKeys.projectsSearch),
        onChanged: _controller.updateSearch,
      ),
    );
    final company = JitanSelectField<int?>(
      label: context.t(AdminTextKeys.projectCompany),
      value: _controller.companyId,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.projectsAllCompanies)),
        for (final MapEntry(key: id, value: name) in seen.entries) JitanSelectOption(value: id, label: name),
      ],
      onChanged: _controller.updateCompany,
    );
    final status = JitanSelectField<int?>(
      label: context.t(AdminTextKeys.projectStatus),
      value: _controller.statusId,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.projectsAllStatuses)),
        for (final s in _statuses) JitanSelectOption(value: s.id, label: s.name),
      ],
      onChanged: _controller.updateStatus,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [search, company, status],
            )
          : Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(width: 420, child: search),
                SizedBox(width: 220, child: company),
                SizedBox(width: 220, child: status),
              ],
            ),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    ProjectsLoading() => _state(GroupStateText(context.t(AdminTextKeys.projectsLoading))),
    ProjectsFailed() => _state(GroupStateText(context.t(AdminTextKeys.projectsLoadFailed), onRetry: _controller.load)),
    ProjectsLoaded(projects: []) => _state(GroupStateText(context.t(AdminTextKeys.projectsEmpty))),
    ProjectsLoaded() => switch (_controller.visible) {
      [] => _state(GroupStateText(context.t(AdminTextKeys.projectsNoMatch))),
      final projects => ProjectsTable(projects: projects, onOpen: _open, onManage: _manage),
    },
  };

  static Widget _state(Widget child) => SliverToBoxAdapter(child: child);
}

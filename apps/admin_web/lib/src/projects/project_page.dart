import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'assign_employees_dialog.dart';
import 'project_dialog.dart';
import 'project_text.dart';

/// One project (Figma `HR / Projects — Project details` 647:1392).
class ProjectPage extends StatefulWidget {
  const ProjectPage({
    super.key,
    required this.companyId,
    required this.projectId,
    required this.api,
    required this.companiesApi,
    required this.employeesApi,
    required this.locationsApi,
  });

  final int companyId;
  final int projectId;
  final ProjectsApi api;
  final CompaniesApi companiesApi;
  final EmployeesApi employeesApi;
  final LocationsApi locationsApi;

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  ProjectDetails? _project;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final project = await widget.api.find(widget.companyId, widget.projectId);
      if (mounted) setState(() => _project = project);
    } on ApiClientException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit(ProjectDetails project) async {
    final saved = await showProjectDialog(
      context,
      api: widget.api,
      companiesApi: widget.companiesApi,
      locationsApi: widget.locationsApi,
      project: project,
    );
    if (saved != null && mounted) setState(() => _project = saved);
  }

  Future<void> _assign(ProjectDetails project) async {
    final saved = await showAssignEmployeesDialog(
      context,
      api: widget.api,
      employeesApi: widget.employeesApi,
      project: project,
    );
    if (saved != null && mounted) setState(() => _project = saved);
  }

  Widget _card({required String title, required Widget action, required Widget child}) => JitanSurfaceCard(
    radius: JitanDimensions.tableCardRadius,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: JitanTextStyles.stateTitle)),
            action,
          ],
        ),
        child,
      ],
    ),
  );

  Widget _details(BuildContext context, ProjectDetails project) {
    final summary = project.summary;
    final end = project.endDate;
    final notes = project.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        _card(
          title: context.t(AdminTextKeys.projectInformation),
          action: JitanSecondaryButton(
            label: context.t(AdminTextKeys.projectManageEdit),
            height: JitanDimensions.controlHeight,
            onPressed: () => _edit(project),
          ),
          child: JitanDetailGrid(
            items: [
              JitanDetailItem(label: context.t(AdminTextKeys.projectCompany), value: summary.companyName),
              JitanDetailItem(label: context.t(AdminTextKeys.projectStart), value: ProjectText.date(context, project.startDate)),
              JitanDetailItem(
                label: context.t(AdminTextKeys.projectEnd),
                value: end == null ? context.t(AdminTextKeys.projectNotSet) : ProjectText.date(context, end),
              ),
              JitanDetailItem(label: context.t(AdminTextKeys.projectType), value: summary.type.name),
              if (project.addressName case final address?)
                JitanDetailItem(label: context.t(AdminTextKeys.projectAddress), value: address),
              if (notes != null) JitanDetailItem(label: context.t(AdminTextKeys.projectDescription), value: notes),
            ],
          ),
        ),
        _card(
          title: context.t(AdminTextKeys.projectAssigned),
          action: JitanPrimaryButton(
            label: context.t(AdminTextKeys.projectManageAssignments),
            height: JitanDimensions.controlHeight,
            onPressed: () => _assign(project),
          ),
          child: project.employees.isEmpty
              ? Text(context.t(AdminTextKeys.projectNoTeam), style: JitanTextStyles.stateMessage)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, employee) in project.employees.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: JitanColors.inputBorder),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ProjectText.employeeName(employee.firstName, employee.lastName, employee.code),
                                overflow: TextOverflow.ellipsis,
                                style: JitanTextStyles.tableCell,
                              ),
                            ),
                            Text(
                              context.t(AdminTextKeys.projectCode, args: {'code': employee.code}),
                              style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final summary = project?.summary;
    final subtitle = summary == null
        ? ''
        : [summary.companyName, summary.reference, summary.status.name].whereType<String>().join(' · ');
    return SingleChildScrollView(
      padding: JitanDimensions.pagePadding(MediaQuery.sizeOf(context).width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          JitanPageHeader(title: summary?.name ?? context.t(AdminTextKeys.projectsTitle), subtitle: subtitle),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go(AdminRoutes.projects),
              icon: const Icon(Icons.arrow_back, size: 16, color: JitanColors.ink),
              label: Text(context.t(AdminTextKeys.projectBack), style: JitanTextStyles.tableCell),
            ),
          ),
          if (project != null)
            _details(context, project)
          else if (_failed)
            GroupStateText(context.t(AdminTextKeys.projectLoadFailed), onRetry: _load)
          else
            GroupStateText(context.t(AdminTextKeys.projectsLoading)),
        ],
      ),
    );
  }
}

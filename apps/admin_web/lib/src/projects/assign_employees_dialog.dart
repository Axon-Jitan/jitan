import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'project_failure_note.dart';
import 'project_text.dart';

/// Chooses who works on [project]. Returns the saved project.
Future<ProjectDetails?> showAssignEmployeesDialog(
  BuildContext context, {
  required ProjectsApi api,
  required EmployeesApi employeesApi,
  required ProjectDetails project,
}) => showJitanModal<ProjectDetails>(
  context,
  barrierDismissible: false,
  builder: (_) => _AssignEmployeesDialog(api: api, employeesApi: employeesApi, project: project),
);

/// Figma `HR / Projects — Assign employees` (`647:1492`): everyone in the
/// project's company, a click to choose.
class _AssignEmployeesDialog extends StatefulWidget {
  const _AssignEmployeesDialog({required this.api, required this.employeesApi, required this.project});

  final ProjectsApi api;
  final EmployeesApi employeesApi;
  final ProjectDetails project;

  @override
  State<_AssignEmployeesDialog> createState() => _AssignEmployeesDialogState();
}

class _AssignEmployeesDialogState extends State<_AssignEmployeesDialog> {
  late final Set<int> _chosen = {for (final e in widget.project.employees) e.id};
  List<EmployeeSummary>? _employees;
  String _search = '';
  ApiClientException? _failure;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final employees = await widget.employeesApi.listForCompany(widget.project.summary.companyId);
      if (mounted) setState(() => _employees = employees);
    } on ApiClientException catch (e) {
      if (mounted) setState(() => _failure = e);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final summary = widget.project.summary;
      final saved = await widget.api.assign(summary.companyId, summary.id, _chosen.toList());
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiClientException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = e;
        });
      }
    }
  }

  List<EmployeeSummary> get _visible => [
    for (final employee in _employees ?? const <EmployeeSummary>[])
      if ('${employee.firstName ?? ''} ${employee.lastName ?? ''} ${employee.code}'.toLowerCase().contains(_search))
        employee,
  ];

  Widget _row(EmployeeSummary employee) {
    final chosen = _chosen.contains(employee.id);
    final radius = BorderRadius.circular(12);
    return Material(
      color: chosen ? JitanColors.inputFill : JitanColors.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: JitanColors.inputBorder)),
      child: InkWell(
        borderRadius: radius,
        onTap: () => setState(() => chosen ? _chosen.remove(employee.id) : _chosen.add(employee.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ProjectText.employeeName(employee.firstName, employee.lastName, employee.code),
                      overflow: TextOverflow.ellipsis,
                      style: JitanTextStyles.tableCellStrong,
                    ),
                    Text(
                      context.t(AdminTextKeys.projectEmployeeCode, args: {'code': employee.code}),
                      style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (chosen) const Icon(Icons.check, size: 18, color: JitanColors.ink),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.project.summary;
    return JitanModal(
      width: 560,
      title: context.t(AdminTextKeys.projectAssignTitle),
      subtitle: context.t(AdminTextKeys.projectAssignText, args: {'project': summary.name, 'company': summary.companyName}),
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.t(AdminTextKeys.projectAssignSearch), style: JitanTextStyles.fieldLabel)),
              Text(context.t(AdminTextKeys.projectAssignChosen, args: {'count': _chosen.length}), style: JitanTextStyles.fieldLabel),
            ],
          ),
          JitanSearchField(
            clearTooltip: context.t(AdminTextKeys.projectAssignClear),
            outlined: true,
            hintText: context.t(AdminTextKeys.projectAssignHint),
            onChanged: (text) => setState(() => _search = text.trim().toLowerCase()),
          ),
          if (_employees == null && _failure == null)
            JitanLoadingState(label: context.t(AdminTextKeys.projectsLoading))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _row(_visible[i]),
              ),
            ),
          if (_failure case final failure?) ProjectFailureNote(failure),
        ],
      ),
      actions: [
        JitanSecondaryButton(label: context.t(AdminTextKeys.periodCancel), onPressed: () => Navigator.of(context).pop()),
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.projectAssignSave),
          onPressed: _employees == null || _busy ? null : _save,
        ),
      ],
    );
  }
}

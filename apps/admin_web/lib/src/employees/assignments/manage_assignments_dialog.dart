import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import 'manage_assignments_controller.dart';

/// Opens "Manage employee assignments" for [employee]; returns `true` when
/// something was saved.
Future<bool> showManageAssignmentsDialog(
  BuildContext context, {
  required EmployeeAssignmentsApi api,
  required EmployeeDetails employee,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => ManageAssignmentsDialog(api: api, employee: employee),
    ) ??
    false;

/// Figma "Admin / Employees — 04 Company assignments modal" (`201:472`) and
/// its sibling tabs. HR and Admin use the same modal.
class ManageAssignmentsDialog extends StatefulWidget {
  const ManageAssignmentsDialog({super.key, required this.api, required this.employee});

  final EmployeeAssignmentsApi api;
  final EmployeeDetails employee;

  @override
  State<ManageAssignmentsDialog> createState() => _ManageAssignmentsDialogState();
}

class _ManageAssignmentsDialogState extends State<ManageAssignmentsDialog> {
  late final _controller = ManageAssignmentsController(
    api: widget.api,
    companyId: widget.employee.companyId,
    userId: widget.employee.id,
  );
  var _tab = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    if (await _controller.save()) navigator.pop(true);
  }

  String _tabLabel(BuildContext context, AssignmentKind kind) => switch (kind) {
    AssignmentKind.companies => context.t(AdminTextKeys.assignmentsTabCompanies),
    AssignmentKind.groups => context.t(AdminTextKeys.assignmentsTabGroups),
  };

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final name = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final tab = _controller.tabs[_tab];
        final failure = _controller.saveFailure;
        return JitanModal(
          title: context.t(AdminTextKeys.assignmentsTitle),
          subtitle: context.t(
            AdminTextKeys.assignmentsSubtitle,
            args: {'name': name.isEmpty ? employee.code : name, 'company': employee.companyName, 'code': employee.code},
          ),
          width: 720,
          onClose: _controller.saving ? null : () => Navigator.of(context).pop(false),
          footerNote: context.t(AdminTextKeys.assignmentsFooter),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1, color: JitanColors.inputBorder),
              const SizedBox(height: 18),
              JitanTabBar(
                labels: [for (final t in _controller.tabs) _tabLabel(context, t.kind)],
                selected: _tab,
                onSelected: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: JitanColors.inputBorder),
              const SizedBox(height: 26),
              switch (tab.kind) {
                AssignmentKind.companies => _CompaniesTab(controller: _controller, tab: tab, currentCompanyId: employee.companyId),
                AssignmentKind.groups => _GroupsTab(controller: _controller, tab: tab),
              },
              if (failure != null) ...[
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final keys = failureTextKeysFor(failure);
                    return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
                  },
                ),
              ],
            ],
          ),
          actions: [
            JitanSecondaryButton(
              label: context.t(CommonTextKeys.cancel),
              onPressed: _controller.saving ? null : () => Navigator.of(context).pop(false),
            ),
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.assignmentsSave),
              busy: _controller.saving,
              onPressed: _controller.hasChanges ? _save : null,
            ),
          ],
        );
      },
    );
  }
}

/// Loading / failure / options for one tab.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.controller, required this.tab, required this.builder});

  final ManageAssignmentsController controller;
  final AssignmentTab tab;
  final Widget Function(List<AssignmentOption> options) builder;

  @override
  Widget build(BuildContext context) {
    final failure = tab.loadFailure;
    if (failure != null) {
      final keys = failureTextKeysFor(failure);
      return SizedBox(
        height: 220,
        child: JitanErrorState(
          title: context.t(keys.title),
          message: context.t(keys.message),
          retryLabel: context.t(CommonTextKeys.retry),
          onRetry: () => controller.retry(tab),
        ),
      );
    }
    final options = tab.options;
    if (options == null) {
      return SizedBox(height: 220, child: JitanLoadingState(label: context.t(AdminTextKeys.assignmentsLoading)));
    }
    return builder(options);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: JitanTextStyles.stateTitle.copyWith(fontSize: 17)),
      const SizedBox(height: 8),
      Text(text, style: JitanTextStyles.modalSubtitle),
      const SizedBox(height: 32),
    ],
  );
}

/// EMP-04: company membership (`tblUserCompany`). Several allowed.
class _CompaniesTab extends StatelessWidget {
  const _CompaniesTab({required this.controller, required this.tab, required this.currentCompanyId});

  final ManageAssignmentsController controller;
  final AssignmentTab tab;
  final int currentCompanyId;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(
        title: context.t(AdminTextKeys.assignmentsCompaniesTitle),
        text: context.t(AdminTextKeys.assignmentsCompaniesText),
      ),
      _TabBody(
        controller: controller,
        tab: tab,
        builder: (options) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in options) ...[
              JitanOptionCard(
                title: option.name,
                detail: context.t(switch (option) {
                  _ when option.id == currentCompanyId => AdminTextKeys.assignmentsCompaniesCurrent,
                  AssignmentOption(isActive: false) => CommonTextKeys.statusInactive,
                  _ => AdminTextKeys.assignmentsCompaniesAdditional,
                }),
                selected: tab.isSelected(option),
                onTap: tab.canToggle(option) && !controller.saving ? () => controller.toggle(tab, option) : null,
              ),
              const SizedBox(height: 13),
            ],
            const SizedBox(height: 18),
            _NoteBox(
              title: context.t(AdminTextKeys.assignmentsCompaniesNoteTitle),
              text: context.t(AdminTextKeys.assignmentsCompaniesNoteText),
            ),
          ],
        ),
      ),
    ],
  );
}

/// EMP-05: employee groups (`tblUserGroup`). Universal across companies (IT,
/// 2026-10-08), so there is no company selector. Several allowed.
class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.controller, required this.tab});

  final ManageAssignmentsController controller;
  final AssignmentTab tab;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(
        title: context.t(AdminTextKeys.assignmentsGroupsTitle),
        text: context.t(AdminTextKeys.assignmentsGroupsText),
      ),
      _TabBody(
        controller: controller,
        tab: tab,
        builder: (options) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in options) ...[
              JitanOptionCard(
                title: option.name,
                detail: context.t(
                  option.isAssigned ? AdminTextKeys.assignmentsGroupsAssigned : AdminTextKeys.assignmentsGroupsAvailable,
                ),
                selected: tab.isSelected(option),
                onTap: tab.canToggle(option) && !controller.saving ? () => controller.toggle(tab, option) : null,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 23),
            Text(context.t(AdminTextKeys.assignmentsGroupsHint), style: JitanTextStyles.stateMessage.copyWith(fontSize: 10)),
            const SizedBox(height: 26),
            _NoteBox(
              title: context.t(AdminTextKeys.assignmentsGroupsNoteTitle),
              text: context.t(AdminTextKeys.assignmentsGroupsNoteText),
            ),
          ],
        ),
      ),
    ],
  );
}

/// The warm-grey explanation box under a tab's options.
class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
    decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(13)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: JitanTextStyles.stateTitle.copyWith(fontSize: 12)),
        const SizedBox(height: 9),
        Text(text, style: JitanTextStyles.stateMessage.copyWith(fontSize: 10)),
      ],
    ),
  );
}

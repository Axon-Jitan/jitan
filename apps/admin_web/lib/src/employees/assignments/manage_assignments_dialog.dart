import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import 'manage_assignments_controller.dart';
import 'remove_assignment_dialog.dart';

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
    AssignmentKind.language => context.t(AdminTextKeys.assignmentsTabLanguage),
    AssignmentKind.credentialGroups => context.t(AdminTextKeys.assignmentsTabAccess),
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
                AssignmentKind.language => _LanguageTab(controller: _controller, tab: tab),
                AssignmentKind.credentialGroups => _AccessTab(controller: _controller, tab: tab),
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

/// EMP-04: company membership (`tblUserCompany`). One company per employee
/// (MVP): the server marks other companies not assignable, so only the
/// employee's own company (or companies, from history) is listed.
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
            for (final option in options.where((o) => o.isAssigned || o.isAssignable)) ...[
              JitanOptionCard(
                title: option.name,
                detail: context.t(switch (option) {
                  _ when option.id == currentCompanyId => AdminTextKeys.assignmentsCompaniesCurrent,
                  AssignmentOption(isRemovable: true) => AdminTextKeys.assignmentsRemovable,
                  AssignmentOption(isActive: false) => CommonTextKeys.statusInactive,
                  _ => AdminTextKeys.assignmentsCompaniesAdditional,
                }),
                selected: tab.isSelected(option),
                removable: option.isRemovable,
                onTap: _onTap(context, controller, tab, option),
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
                detail: switch (option) {
                  AssignmentOption(isRemovable: true) => context.t(AdminTextKeys.assignmentsRemovable),
                  AssignmentOption(isAssigned: false) => context.t(AdminTextKeys.assignmentsGroupsAvailable),
                  _ => null,
                },
                selected: tab.isSelected(option),
                removable: option.isRemovable,
                onTap: _onTap(context, controller, tab, option),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 23),
            Text(context.t(AdminTextKeys.assignmentsGroupsHint), style: JitanTextStyles.stateMessage.copyWith(fontSize: 14)),
          ],
        ),
      ),
    ],
  );
}

/// EMP-06: the one preferred language (`tblUserLanguage`), radio choice
/// from `tblLanguage`. Saving replaces it (a preference update).
class _LanguageTab extends StatelessWidget {
  const _LanguageTab({required this.controller, required this.tab});

  final ManageAssignmentsController controller;
  final AssignmentTab tab;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(
        title: context.t(AdminTextKeys.assignmentsLanguageTitle),
        text: context.t(AdminTextKeys.assignmentsLanguageText),
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
                detail: switch (option.code) {
                  final code? => context.tOrNull(CommonTextKeys.languageName(code)),
                  null => null,
                },
                indicator: JitanOptionIndicator.radio,
                height: 60,
                selected: tab.isSelected(option),
                onTap: tab.canToggle(option) && !controller.saving ? () => controller.toggle(tab, option) : null,
              ),
              const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    ],
  );
}

/// EMP-07: credential groups (`tblUserCredGroup`), names from the database.
/// The picker offers what can be added; existing ones are listed below and
/// stay until IT confirms removal (CLARIFY-09).
class _AccessTab extends StatelessWidget {
  const _AccessTab({required this.controller, required this.tab});

  final ManageAssignmentsController controller;
  final AssignmentTab tab;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(
        title: context.t(AdminTextKeys.assignmentsAccessTitle),
        text: context.t(AdminTextKeys.assignmentsAccessText),
      ),
      _TabBody(
        controller: controller,
        tab: tab,
        builder: (options) {
          final assigned = [for (final o in options) if (o.isAssigned) o];
          final chosen = tab.pending.firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JitanSelectField<int>(
                key: ValueKey(chosen),
                hintText: context.t(AdminTextKeys.assignmentsAccessPicker),
                value: chosen,
                options: [
                  for (final o in options)
                    if (tab.canToggle(o)) JitanSelectOption(value: o.id, label: o.name),
                ],
                onChanged: controller.saving ? null : (id) => controller.choose(tab, id),
              ),
              const SizedBox(height: 24),
              Container(
                constraints: const BoxConstraints(minHeight: 118),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t(AdminTextKeys.assignmentsAccessCurrent), style: JitanTextStyles.stateTitle.copyWith(fontSize: 16)),
                    const SizedBox(height: 18),
                    if (assigned.isEmpty)
                      Text(context.t(AdminTextKeys.assignmentsAccessNone), style: JitanTextStyles.stateMessage.copyWith(fontSize: 15))
                    else
                      for (final o in assigned)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(o.name, style: JitanTextStyles.tableCell.copyWith(fontSize: 16)),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 29),
              Text(context.t(AdminTextKeys.assignmentsAccessHint), style: JitanTextStyles.stateMessage.copyWith(fontSize: 14)),
            ],
          );
        },
      ),
    ],
  );
}

/// Tapping an option: a current, removable assignment asks to confirm its
/// removal (Figma 207:329 / 207:441); an assignable one is ticked to be
/// added on Save; anything else is locked.
VoidCallback? _onTap(BuildContext context, ManageAssignmentsController controller, AssignmentTab tab, AssignmentOption option) {
  if (controller.saving || controller.removing) return null;
  if (option.isRemovable) {
    return () => showRemoveAssignmentDialog(context, controller: controller, tab: tab, option: option);
  }
  return tab.canToggle(option) ? () => controller.toggle(tab, option) : null;
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
        Text(title, style: JitanTextStyles.stateTitle.copyWith(fontSize: 16)),
        const SizedBox(height: 9),
        Text(text, style: JitanTextStyles.stateMessage.copyWith(fontSize: 14)),
      ],
    ),
  );
}

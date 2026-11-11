import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import '../../schedules/schedule_summary_text.dart';
import 'manage_assignments_controller.dart';
import 'remove_assignment_dialog.dart';

/// Opens "Companies, groups and access" for [employee]; returns `true` when
/// something was saved. With [schedulesApi], each group shows its hours.
Future<bool> showManageAssignmentsDialog(
  BuildContext context, {
  required EmployeeAssignmentsApi api,
  required EmployeeDetails employee,
  SchedulesApi? schedulesApi,
}) async =>
    await showJitanModal<bool>(
      context,
      builder: (_) => ManageAssignmentsDialog(api: api, employee: employee, schedulesApi: schedulesApi),
    ) ??
    false;

/// Figma "Companies, groups and access" (`1537:2` companies, `1537:194`
/// groups, `1537:372` language, `1537:556` access): the employee's name,
/// four tabs like the rest of the app, and one plain list per tab with a ✓
/// on what applies. Every tab keeps the same height. HR and Admin use the
/// same pop-up.
///
/// What a tap does is the server's rule ([AssignmentOption]): a current,
/// removable company or group asks to confirm its removal; an assignable
/// one is ticked and added on Save; the rest is locked. A language replaces
/// the one chosen; an access role is added on Save, and the current ones
/// stay until IT confirms removal (CLARIFY-09).
class ManageAssignmentsDialog extends StatefulWidget {
  const ManageAssignmentsDialog({super.key, required this.api, required this.employee, this.schedulesApi});

  final EmployeeAssignmentsApi api;
  final EmployeeDetails employee;
  final SchedulesApi? schedulesApi;

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

  String get _firstName {
    final e = widget.employee;
    return e.firstName ?? e.code;
  }

  /// Each group's hours, by group id, once known.
  Map<int, String> _hours = const {};

  /// The list's height, the same on every tab (Figma: 276).
  static const _listHeight = 276.0;

  @override
  void initState() {
    super.initState();
    _loadHours();
  }

  Future<void> _loadHours() async {
    final api = widget.schedulesApi;
    if (api == null) return;
    try {
      final schedules = await api.groupSchedules();
      if (!mounted) return;
      final t = TranslationScope.of(context);
      setState(
        () => _hours = {
          for (final s in schedules)
            if (s.status == GroupScheduleStatus.configured && s.variants.length == 1) s.group.id: workHoursDaysSummary(t, s.variants.single),
        },
      );
    } on ApiClientException {
      // Only the hours beside the groups depend on it.
    }
  }

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

  String _note(BuildContext context, AssignmentKind kind, String name) => context.t(switch (kind) {
    AssignmentKind.companies => AdminTextKeys.assignmentsCompaniesNote,
    AssignmentKind.groups => AdminTextKeys.assignmentsGroupsNote,
    AssignmentKind.language => AdminTextKeys.assignmentsLanguageNote,
    AssignmentKind.credentialGroups => AdminTextKeys.assignmentsAccessNote,
  }, args: {'name': name});

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final fullName = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final name = employee.firstName ?? (fullName.isEmpty ? employee.code : fullName);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final tab = _controller.tabs[_tab];
        final failure = _controller.saveFailure;
        return JitanModal(
          width: 520,
          title: fullName.isEmpty ? employee.code : fullName,
          subtitle: context.t(AdminTextKeys.assignmentsTitle),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: JitanPillSwitch<int>(
                  options: [for (final (i, t) in _controller.tabs.indexed) (i, _tabLabel(context, t.kind))],
                  value: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(height: 16),
              Text(_note(context, tab.kind, name), style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
              const SizedBox(height: 10),
              SizedBox(height: _listHeight, child: _list(context, tab)),
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
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 10,
              children: [
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
            ),
          ],
        );
      },
    );
  }

  /// One tab's list: loading, a failure with retry, or its options.
  Widget _list(BuildContext context, AssignmentTab tab) {
    final failure = tab.loadFailure;
    if (failure != null) {
      final keys = failureTextKeysFor(failure);
      return JitanErrorState(
        title: context.t(keys.title),
        message: context.t(keys.message),
        retryLabel: context.t(CommonTextKeys.retry),
        onRetry: () => _controller.retry(tab),
      );
    }
    final options = tab.options;
    if (options == null) return JitanLoadingState(label: context.t(AdminTextKeys.assignmentsLoading));
    final shown = switch (tab.kind) {
      // Only companies they are in or can join.
      AssignmentKind.companies => [for (final o in options) if (o.isAssigned || o.isAssignable) o],
      _ => options,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: JitanColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JitanColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: shown.length,
          separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: JitanColors.cardBorder),
          itemBuilder: (context, i) => _row(context, tab, shown[i]),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AssignmentTab tab, AssignmentOption option) {
    final selected = tab.isSelected(option);
    final onTap = switch (tab.kind) {
      AssignmentKind.language || AssignmentKind.credentialGroups =>
        tab.canToggle(option) && !_controller.saving
            ? () => tab.kind == AssignmentKind.language ? _controller.toggle(tab, option) : _controller.choose(tab, option.id)
            : null,
      _ => _onTap(context, _controller, tab, option, _firstName),
    };
    final note = switch (tab.kind) {
      AssignmentKind.groups => _hours[option.id],
      AssignmentKind.companies when !option.isActive => context.t(CommonTextKeys.statusInactive),
      _ => null,
    };
    final locked = onTap == null && !selected;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            spacing: 10,
            children: [
              // The name and its note on the left; the check at the far right.
              Expanded(
                child: Row(
                  spacing: 10,
                  children: [
                    Flexible(
                      child: Text(
                        option.name,
                        overflow: TextOverflow.ellipsis,
                        style: JitanTextStyles.tableCell.copyWith(
                          fontSize: 15,
                          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                          color: locked ? JitanColors.disabledText : JitanColors.ink,
                        ),
                      ),
                    ),
                    if (note != null)
                      Text(note, style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.disabledText)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check, size: 18, color: JitanColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tapping a company or group: a current, removable one asks to confirm its
/// removal; an assignable one is ticked to be added on Save; anything else
/// is locked.
VoidCallback? _onTap(
  BuildContext context,
  ManageAssignmentsController controller,
  AssignmentTab tab,
  AssignmentOption option,
  String name,
) {
  if (controller.saving || controller.removing) return null;
  if (option.isRemovable) {
    return () => showRemoveAssignmentDialog(context, controller: controller, tab: tab, option: option, name: name);
  }
  return tab.canToggle(option) ? () => controller.toggle(tab, option) : null;
}

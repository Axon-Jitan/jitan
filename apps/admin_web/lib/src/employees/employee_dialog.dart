import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_summary_text.dart';
import 'employee_standing.dart';

/// What HR chose in an employee's pop-up; the Employees page carries it out.
enum EmployeeChoice { assignments, resetAccess, setUpQr, deactivate, reactivate }

/// Opens an employee (Figma `1534:2`, not set up yet `1531:459`, inactive
/// `1534:188`): what HR
/// chose, with the employee's details, or `null` when closed.
Future<(EmployeeChoice, EmployeeDetails)?> showEmployeeDialog(
  BuildContext context, {
  required EmployeesApi api,
  required EmployeeSummary employee,
  required int companyId,
  required List<CompanySummary> companies,
}) => showJitanModal<(EmployeeChoice, EmployeeDetails)>(
  context,
  builder: (_) => EmployeeDialog(api: api, employee: employee, companyId: companyId, companies: companies),
);

/// An employee in a pop-up: who they are and how they stand, then the
/// actions that apply to them, and a quiet Deactivate (or Reactivate) on the
/// left. Only the action that fits the account shows: Reset account access
/// once it is set up, the onboarding QR before (the recovery QR after a
/// reset). An inactive employee shows no actions, only what that means.
class EmployeeDialog extends StatefulWidget {
  const EmployeeDialog({
    super.key,
    required this.api,
    required this.employee,
    required this.companyId,
    required this.companies,
  });

  final EmployeesApi api;
  final EmployeeSummary employee;

  /// The company the details are asked through: the one HR filters on, or
  /// one of the employee's (HR may open any company in V1; the answer is
  /// the same person).
  final int companyId;

  /// Every company, to name the employee's.
  final List<CompanySummary> companies;

  @override
  State<EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<EmployeeDialog> {
  EmployeeDetails? _details;
  ApiClientException? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final details = await widget.api.details(widget.companyId, widget.employee.id);
      if (mounted) setState(() => _details = details);
    } on ApiClientException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    }
  }

  void _choose(EmployeeChoice choice) => Navigator.of(context).pop((choice, _details!));

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final standing = EmployeeStanding.ofSummary(employee);
    final name = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final details = _details;
    return JitanModal(
      width: 460,
      title: name.isEmpty ? employee.code : name,
      subtitle: '${employee.code} · ${standing.label(context)}',
      body: switch ((details, _failure)) {
        (final details?, _) => _content(context, details),
        (_, final failure?) => _error(context, failure),
        _ => SizedBox(height: 240, child: JitanLoadingState(label: context.t(AdminTextKeys.employeeLoading))),
      },
      leadingActions: [
        TextButton(
          onPressed: details == null
              ? null
              : () => _choose(employee.isActive ? EmployeeChoice.deactivate : EmployeeChoice.reactivate),
          style: TextButton.styleFrom(
            foregroundColor: employee.isActive ? JitanColors.errorStrong : JitanColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            context.t(employee.isActive ? AdminTextKeys.employeeDeactivate : AdminTextKeys.employeeReactivate),
            style: JitanTextStyles.tableCellStrong.copyWith(
              color: employee.isActive ? JitanColors.errorStrong : JitanColors.ink,
            ),
          ),
        ),
      ],
      actions: [
        JitanSecondaryButton(label: context.t(AdminTextKeys.employeeClose), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _content(BuildContext context, EmployeeDetails details) {
    final employee = widget.employee;
    final t = TranslationScope.of(context);
    final unavailable = context.t(CommonTextKeys.valueUnavailable);
    final companies = [
      for (final c in widget.companies)
        if (employee.companyIds.contains(c.id)) c.name,
    ];
    final setUp = details.isActivated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: JitanColors.tableHeader, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              _fact(context.t(AdminTextKeys.employeeFactCompanies), companies.isEmpty ? unavailable : companies.join(', ')),
              _fact(context.t(AdminTextKeys.employeeFactType), employee.groups.isEmpty ? unavailable : employee.groups.join(', ')),
              _fact(
                context.t(AdminTextKeys.employeeFactSchedule),
                switch (employee.schedule) {
                  final schedule? when schedule.workDays.isNotEmpty => workHoursDaysSummary(t, schedule),
                  _ => unavailable,
                },
              ),
              _fact(context.t(AdminTextKeys.employeeFactPhone), details.phone ?? unavailable),
              _fact(
                context.t(AdminTextKeys.employeeFactAccount),
                context.t(setUp ? AdminTextKeys.employeeSetUp : AdminTextKeys.employeeNotSetUp),
                color: setUp ? null : JitanColors.warning,
              ),
            ],
          ),
        ),
        if (!employee.isActive) ...[
          const SizedBox(height: 14),
          Text(
            context.t(AdminTextKeys.employeeInactiveNote, args: {'name': employee.firstName ?? employee.code}),
            style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
          ),
        ] else ...[
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: JitanColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JitanColors.cardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                _link(context.t(AdminTextKeys.employeeAssignments), () => _choose(EmployeeChoice.assignments)),
                const Divider(height: 1, thickness: 1, color: JitanColors.cardBorder),
                if (setUp)
                  _link(context.t(AdminTextKeys.employeeResetAccess), () => _choose(EmployeeChoice.resetAccess))
                else
                  _link(
                    // After Reset account access the recovery QR applies;
                    // onboarding is only for an account that never had a
                    // password (server rule).
                    context.t(details.accessResetPending ? AdminTextKeys.employeeShowRecoveryQr : AdminTextKeys.employeeShowSetUpQr),
                    () => _choose(EmployeeChoice.setUpQr),
                  ),
              ],
            ),
          ),
        ),
        ],
      ],
    );
  }

  Widget _fact(String label, String value, {Color? color}) => SizedBox(
    height: 46,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: JitanTextStyles.tableCellStrong.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _link(String label, VoidCallback onTap) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: Text(label, style: JitanTextStyles.tableCellStrong)),
              const Icon(Icons.chevron_right, size: 18, color: JitanColors.ink),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return SizedBox(
      height: 240,
      child: JitanErrorState(
        title: context.t(keys.title),
        message: context.t(keys.message),
        retryLabel: context.t(CommonTextKeys.retry),
        onRetry: _load,
      ),
    );
  }
}

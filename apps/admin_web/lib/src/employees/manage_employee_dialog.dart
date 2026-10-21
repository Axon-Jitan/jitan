import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// What HR picked in "Manage employee".
enum EmployeeAction { onboardingQr, resetAccess, remove }

Future<EmployeeAction?> showManageEmployeeDialog(BuildContext context, {required EmployeeSummary employee}) =>
    showJitanModal<EmployeeAction>(context, builder: (_) => ManageEmployeeDialog(employee: employee));

/// Figma `HR / Employees — Manage account actions` (1399:10): the row's "⋯",
/// with "Remove employee" from `Manage employee` (238:3689).
/// An onboarding QR is only for an employee who has not activated yet, and
/// Reset account access only for one who has (server rules); the other one
/// is shown unavailable rather than leading to a refusal.
class ManageEmployeeDialog extends StatelessWidget {
  const ManageEmployeeDialog({super.key, required this.employee});

  final EmployeeSummary employee;

  @override
  Widget build(BuildContext context) {
    final name = [employee.firstName, employee.lastName].whereType<String>().join(' ');
    final state = context.t(employee.isActivated ? AdminTextKeys.employeeOnboardingActivated : AdminTextKeys.employeeOnboardingNotActivated);
    final choices = [
      (EmployeeAction.onboardingQr, AdminTextKeys.employeeManageQr, AdminTextKeys.employeeManageQrText, !employee.isActivated),
      (EmployeeAction.resetAccess, AdminTextKeys.employeeManageReset, AdminTextKeys.employeeManageResetText, employee.isActivated),
      (EmployeeAction.remove, AdminTextKeys.employeeManageRemove, AdminTextKeys.employeeManageRemoveText, true),
    ];
    return JitanModal(
      width: 480,
      title: context.t(AdminTextKeys.employeeManageTitle),
      subtitle: '${name.isEmpty ? employee.code : name} · $state',
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (action, title, text, available)) in choices.indexed) ...[
            if (index > 0) const Divider(height: 1, color: JitanColors.inputBorder),
            InkWell(
              onTap: available ? () => Navigator.of(context).pop(action) : null,
              borderRadius: BorderRadius.circular(12),
              hoverColor: JitanColors.warmWhite,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t(title),
                            style: JitanTextStyles.stateTitle.copyWith(color: available ? JitanColors.ink : JitanColors.disabledText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t(text),
                            style: JitanTextStyles.stateMessage.copyWith(
                              fontSize: 13,
                              color: available ? null : JitanColors.disabledText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: available ? JitanColors.inkMuted : JitanColors.disabledText),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'onboarding_qr_dialog.dart';
import 'reset_access_dialog.dart';

/// Opens the Employee details modal for [userId] in [companyId].
Future<void> showEmployeeDetailsDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required int companyId,
  required int userId,
}) => showDialog<void>(
  context: context,
  builder: (_) => EmployeeDetailsDialog(employeesApi: employeesApi, companyId: companyId, userId: userId),
);

/// Figma `Admin / Employees — Employee details modal` (`153:357`).
///
/// Differences from Figma, on purpose: **Location** (ERD GAP-11) shows "—"
/// with an explanation; **Work policy** is omitted
/// (PRODUCT-CLARIFY-EMPLOYEE-POLICY). **Account** and the Onboarding status
/// follow `userPassword IS NOT NULL` (activated). "Reset account access"
/// (bottom left, Figma `196:149`) starts HR/Admin-assisted recovery; it is
/// disabled until the employee has activated (nothing to reset before).
class EmployeeDetailsDialog extends StatefulWidget {
  const EmployeeDetailsDialog({super.key, required this.employeesApi, required this.companyId, required this.userId});

  final EmployeesApi employeesApi;
  final int companyId;
  final int userId;

  @override
  State<EmployeeDetailsDialog> createState() => _EmployeeDetailsDialogState();
}

class _EmployeeDetailsDialogState extends State<EmployeeDetailsDialog> {
  EmployeeDetails? _details;
  ApiClientException? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _details = null;
      _failure = null;
    });
    try {
      final details = await widget.employeesApi.details(widget.companyId, widget.userId);
      if (mounted) setState(() => _details = details);
    } on ApiClientException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) => JitanModal(
    title: context.t(AdminTextKeys.employeeDetailsTitle),
    body: switch ((_details, _failure)) {
      (final details?, _) => _content(context, details),
      (_, final failure?) => _error(context, failure),
      _ => SizedBox(height: 200, child: JitanLoadingState(label: context.t(AdminTextKeys.employeeDetailsLoading))),
    },
  );

  Widget _content(BuildContext context, EmployeeDetails details) {
    final unavailable = context.t(CommonTextKeys.valueUnavailable);
    final name = [details.firstName, details.lastName].whereType<String>().join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name.isEmpty ? unavailable : name, style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
        const SizedBox(height: 6),
        Text(
          context.t(
            AdminTextKeys.employeeDetailsSubtitle,
            args: {'company': details.companyName, 'code': details.code},
          ),
          style: JitanTextStyles.modalSubtitle,
        ),
        const SizedBox(height: 26),
        JitanDetailGrid(
          items: [
            JitanDetailItem(
              label: context.t(AdminTextKeys.employeeFieldType),
              value: details.groups.isEmpty ? unavailable : details.groups.join(', '),
            ),
            JitanDetailItem(
              label: context.t(AdminTextKeys.employeeFieldLocation),
              value: unavailable,
              tooltip: context.t(AdminTextKeys.employeeLocationUnavailable),
            ),
            JitanDetailItem(label: context.t(AdminTextKeys.employeeFieldPhone), value: details.phone ?? unavailable),
            JitanDetailItem(
              label: context.t(AdminTextKeys.employeeFieldAccount),
              value: context.t(
                details.isActivated
                    ? AdminTextKeys.employeeOnboardingActivated
                    : AdminTextKeys.employeeOnboardingNotActivated,
              ),
            ),
            JitanDetailItem(
              label: context.t(AdminTextKeys.employeeFieldStatus),
              value: context.t(details.isActive ? CommonTextKeys.statusActive : CommonTextKeys.statusInactive),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _OnboardingCard(
          activated: details.isActivated,
          onShowQr: () => showOnboardingQrDialog(context, employeesApi: widget.employeesApi, employee: details),
        ),
        const SizedBox(height: 32),
        Align(
          alignment: Alignment.centerLeft,
          child: JitanSecondaryButton(
            label: context.t(AdminTextKeys.employeeResetAccessAction),
            foreground: JitanColors.errorStrong,
            tooltip: details.isActivated ? null : context.t(AdminTextKeys.employeeResetAccessUnavailable),
            onPressed: details.isActivated ? () => _resetAccess(context, details) : null,
          ),
        ),
      ],
    );
  }

  Future<void> _resetAccess(BuildContext context, EmployeeDetails details) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = [details.firstName, details.lastName].whereType<String>().join(' ');
    final success = context.t(AdminTextKeys.employeeResetAccessSuccess, args: {'name': name.isEmpty ? details.code : name});
    if (!await showResetAccessDialog(context, employeesApi: widget.employeesApi, employee: details)) return;
    messenger?.showSnackBar(SnackBar(content: Text(success)));
    // The server is the source of truth: reload to show "Not activated".
    await _load();
  }

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

/// Figma's Onboarding card (`153:357`): status, explanation, QR action.
/// Once activated, the same QR is the employee's personal Terminal QR.
class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.activated, required this.onShowQr});

  final bool activated;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: JitanColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: JitanColors.inputBorder),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(AdminTextKeys.employeeOnboardingTitle),
            style: JitanTextStyles.stateTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            context.t(
              activated ? AdminTextKeys.employeeOnboardingActivated : AdminTextKeys.employeeOnboardingNotActivated,
            ),
            style: JitanTextStyles.tableCellStrong.copyWith(
              color: activated ? JitanColors.success : JitanColors.warning,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.t(activated ? AdminTextKeys.employeeOnboardingCompletedText : AdminTextKeys.employeeOnboardingText),
            style: JitanTextStyles.modalSubtitle,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: JitanPrimaryButton(
              label: context.t(
                activated ? AdminTextKeys.employeeOnboardingShowQr : AdminTextKeys.employeeOnboardingAction,
              ),
              onPressed: onShowQr,
            ),
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import 'activity_controller.dart';

/// The company at the top of Home, for someone in several (Figma `691:71`):
/// tap to register today's time for another one.
class CompanyPicker extends StatelessWidget {
  const CompanyPicker({super.key, required this.controller});

  final ActivityController controller;

  MyCompany? get _shown {
    final activity = controller.activity;
    return activity.current?.company ??
        activity.companies.where((c) => c.isDefault).firstOrNull ??
        activity.companies.firstOrNull;
  }

  Future<void> _open(BuildContext context) => showJitanModal<void>(
    context,
    builder: (_) => _CompanyDialog(controller: controller, shown: _shown),
  );

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => _open(context),
    style: OutlinedButton.styleFrom(
      foregroundColor: JitanColors.ink,
      backgroundColor: JitanColors.surface,
      side: const BorderSide(color: JitanColors.inputBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(_shown?.name ?? '', style: JitanMobileTextStyles.cardText.copyWith(color: JitanColors.ink)),
        const Icon(Icons.keyboard_arrow_down, size: 18),
      ],
    ),
  );
}

class _CompanyDialog extends StatefulWidget {
  const _CompanyDialog({required this.controller, required this.shown});

  final ActivityController controller;
  final MyCompany? shown;

  @override
  State<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<_CompanyDialog> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _pick(MyCompany company) async {
    if (company.id == widget.shown?.id) return Navigator.of(context).pop();
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.controller.switchTo(kind: ActivityKind.work, companyId: company.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiClientException {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = widget.controller.activity.companies;
    final fallback = companies.where((c) => c.isDefault).firstOrNull;
    return JitanModal(
      title: context.t(EmployeeTextKeys.activityRegisterFor),
      subtitle: context.t(EmployeeTextKeys.activityRegisterForText),
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final company in companies)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _busy ? null : () => _pick(company),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(company.name, style: JitanMobileTextStyles.cardTitle),
                          Text(
                            context.t(company.isDefault ? EmployeeTextKeys.activityDefaultCompany : EmployeeTextKeys.activityAssignedCompany),
                            style: JitanMobileTextStyles.cardText,
                          ),
                        ],
                      ),
                    ),
                    if (company.id == widget.shown?.id) const Icon(Icons.check, size: 18, color: JitanColors.ink),
                  ],
                ),
              ),
            ),
          if (fallback != null) ...[
            const SizedBox(height: 10),
            Text(
              context.t(EmployeeTextKeys.activityDefaultReturns, args: {'company': fallback.name}),
              style: JitanMobileTextStyles.cardText,
            ),
          ],
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(context.t(EmployeeTextKeys.activitySwitchFailed), style: JitanTextStyles.fieldError),
          ],
        ],
      ),
    );
  }
}

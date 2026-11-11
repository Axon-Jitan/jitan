import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'company_text.dart';

/// What a company pop-up did, once the server confirmed.
enum CompanyChange { renamed, deactivated, reactivated, openEmployees }

/// Opens a company (Figma `1524:105`); what changed and the company as the
/// server answered, or `null` when closed without a change.
Future<(CompanyChange, CompanySummary)?> showCompanyDialog(
  BuildContext context, {
  required CompaniesApi api,
  required CompanySummary company,
  required List<CompanySummary> companies,
}) => showJitanModal<(CompanyChange, CompanySummary)>(
  context,
  builder: (_) => CompanyDialog(api: api, company: company, companies: companies),
);

/// A company in a pop-up: its name to edit (Save stays off until it
/// changes), its employees with a way to them, when it last changed, and a
/// quiet Deactivate (or Reactivate) on the left, saved at once.
class CompanyDialog extends StatefulWidget {
  const CompanyDialog({super.key, required this.api, required this.company, required this.companies});

  final CompaniesApi api;
  final CompanySummary company;

  /// Every loaded company, for the name check while typing.
  final List<CompanySummary> companies;

  @override
  State<CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<CompanyDialog> {
  late final _name = TextEditingController(text: widget.company.name);
  bool _busy = false;
  bool _failed = false;
  String? _serverTaken;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _serverTaken = null));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CompanySummary? get _taken {
    final typed = CompanyText.comparable(_name.text);
    return widget.companies
        .where((c) => c.id != widget.company.id && typed.isNotEmpty && CompanyText.comparable(c.name) == typed)
        .firstOrNull;
  }

  bool get _changed => _name.text.trim() != widget.company.name;
  bool get _ready => _changed && _name.text.trim().isNotEmpty && _taken == null && !_busy;

  Future<void> _run(CompanyChange change, Future<CompanySummary> Function() call) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final company = await call();
      if (mounted) Navigator.of(context).pop((change, company));
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.error?.code == ApiErrorCode.duplicateCompanyName) {
          _serverTaken = _name.text.trim();
        } else {
          _failed = true;
        }
      });
    }
  }

  void _save() {
    if (_ready) _run(CompanyChange.renamed, () => widget.api.rename(widget.company.id, CompanyRequest(name: _name.text.trim())));
  }

  Widget _fact(String label, Widget value) => SizedBox(
    height: 46,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(label, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted))),
          value,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    final taken = _taken?.name ?? _serverTaken;
    final updated = company.lastUpdatedAt;
    return JitanModal(
      width: 460,
      title: company.name,
      subtitle: context.t(company.isActive ? CommonTextKeys.statusActive : CommonTextKeys.statusInactive),
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanTextField(
            label: context.t(AdminTextKeys.companyName),
            controller: _name,
            maxLength: CompanyRequest.maxNameLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            errorText: taken == null ? null : context.t(AdminTextKeys.companyNameTaken, args: {'name': taken}),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: BoxDecoration(color: JitanColors.tableHeader, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _fact(
                  context.t(AdminTextKeys.companyEmployees),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 14,
                    children: [
                      Text('${company.employeeCount}', style: JitanTextStyles.tableCellStrong),
                      TextButton(
                        onPressed: _busy ? null : () => Navigator.of(context).pop((CompanyChange.openEmployees, company)),
                        style: TextButton.styleFrom(foregroundColor: JitanColors.ink, padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            Text(context.t(AdminTextKeys.companyViewEmployees), style: JitanTextStyles.tableCellStrong),
                            const Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _fact(
                  context.t(AdminTextKeys.companyLastUpdated),
                  Text(
                    updated == null ? context.t(CommonTextKeys.valueUnavailable) : CompanyText.updatedExactly(context, updated),
                    style: JitanTextStyles.tableCellStrong,
                  ),
                ),
              ],
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: 12),
            Text(context.t(AdminTextKeys.companySaveFailed), style: JitanTextStyles.fieldError),
          ],
        ],
      ),
      leadingActions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => company.isActive
                    ? _run(CompanyChange.deactivated, () => widget.api.deactivate(company.id))
                    : _run(CompanyChange.reactivated, () => widget.api.reactivate(company.id)),
          style: TextButton.styleFrom(
            foregroundColor: company.isActive ? JitanColors.errorStrong : JitanColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            context.t(company.isActive ? AdminTextKeys.companyDeactivate : AdminTextKeys.companyReactivate),
            style: JitanTextStyles.tableCellStrong.copyWith(
              color: company.isActive ? JitanColors.errorStrong : JitanColors.ink,
            ),
          ),
        ),
      ],
      actions: [
        JitanSecondaryButton(label: context.t(AdminTextKeys.companyClose), onPressed: () => Navigator.of(context).pop()),
        JitanPrimaryButton(label: context.t(AdminTextKeys.companySave), busy: _busy, onPressed: _ready ? _save : null),
      ],
    );
  }
}

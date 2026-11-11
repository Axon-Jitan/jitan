import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'company_text.dart';

/// Opens Add company; the company the server added, or `null`.
Future<CompanySummary?> showAddCompanyDialog(
  BuildContext context, {
  required CompaniesApi api,
  required List<CompanySummary> companies,
}) => showJitanModal<CompanySummary>(context, builder: (_) => AddCompanyDialog(api: api, companies: companies));

/// Add company (Figma `1524:233`): only the name, ready to type. A name
/// already in Jitan is said under the field while typing; the server decides.
class AddCompanyDialog extends StatefulWidget {
  const AddCompanyDialog({super.key, required this.api, required this.companies});

  final CompaniesApi api;

  /// The companies already loaded, for the name check while typing.
  final List<CompanySummary> companies;

  @override
  State<AddCompanyDialog> createState() => _AddCompanyDialogState();
}

class _AddCompanyDialogState extends State<AddCompanyDialog> {
  final _name = TextEditingController();
  bool _busy = false;

  /// What the server refused, by text key and its arguments.
  (String, Map<String, Object>)? _serverError;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _serverError = null));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CompanySummary? get _taken {
    final typed = CompanyText.comparable(_name.text);
    return typed.isEmpty ? null : widget.companies.where((c) => CompanyText.comparable(c.name) == typed).firstOrNull;
  }

  bool get _ready => _name.text.trim().isNotEmpty && _taken == null && !_busy;

  Future<void> _add() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final company = await widget.api.create(CompanyRequest(name: _name.text.trim()));
      if (mounted) Navigator.of(context).pop(company);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.error?.code == ApiErrorCode.duplicateCompanyName) {
          _serverError = (AdminTextKeys.companyNameTaken, {'name': _name.text.trim()});
        } else {
          _failed = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final taken = _taken;
    final error = taken != null
        ? context.t(AdminTextKeys.companyNameTaken, args: {'name': taken.name})
        : _serverError == null
        ? null
        : context.t(_serverError!.$1, args: _serverError!.$2);
    return JitanModal(
      width: 440,
      title: context.t(AdminTextKeys.companyAdd),
      subtitle: context.t(AdminTextKeys.companyAddText),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanTextField(
            label: context.t(AdminTextKeys.companyName),
            controller: _name,
            autofocus: true,
            maxLength: CompanyRequest.maxNameLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            errorText: error,
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(context.t(AdminTextKeys.companySaveFailed), style: JitanTextStyles.fieldError),
          ],
        ],
      ),
      actions: [
        JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: () => Navigator.of(context).pop()),
        JitanPrimaryButton(label: context.t(AdminTextKeys.companyAdd), busy: _busy, onPressed: _ready ? _add : null),
      ],
    );
  }
}

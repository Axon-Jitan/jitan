import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'current_company.dart';

/// "Current company" (Figma `HR / Employees — Company switcher open`
/// 1401:2, `No company selected` 1401:121): the company HR works in, chosen
/// from every non-deleted company. Nothing is chosen for HR (§20: never
/// silently pick the first company).
class CompanySwitcher extends StatefulWidget {
  const CompanySwitcher({super.key, required this.companiesApi});

  final CompaniesApi companiesApi;

  @override
  State<CompanySwitcher> createState() => _CompanySwitcherState();
}

class _CompanySwitcherState extends State<CompanySwitcher> {
  List<CompanySummary>? _companies;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final companies = await widget.companiesApi.listCompanies();
      if (mounted) setState(() => _companies = companies);
    } on ApiClientException {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = CurrentCompanyScope.of(context);
    final companies = _companies ?? const <CompanySummary>[];
    return JitanSelectField<int>(
      label: context.t(AdminTextKeys.employeeFilterCompany),
      hintText: context.t(_failed ? AdminTextKeys.employeeFilterCompanyFailed : AdminTextKeys.employeeFilterCompanyHint),
      value: current.company?.id,
      options: [for (final company in companies) JitanSelectOption(value: company.id, label: company.name)],
      onChanged: _failed
          ? (_) => _load()
          : _companies == null
          ? null
          : (id) => current.select(companies.where((c) => c.id == id).firstOrNull),
    );
  }
}

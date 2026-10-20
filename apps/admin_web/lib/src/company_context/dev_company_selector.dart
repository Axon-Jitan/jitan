import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'current_company.dart';

/// DEVELOPMENT ONLY: a bar to choose the current company.
///
/// Stands in for the company switcher that is not designed yet. Shown only
/// when the build enables dev tools (`JITAN_DEV_TOOLS=true`). It chooses
/// which company the pages ask the server about; the server still authorizes
/// every request for that company.
class DevCompanySelector extends StatefulWidget {
  const DevCompanySelector({super.key, required this.companiesApi});

  final CompaniesApi companiesApi;

  @override
  State<DevCompanySelector> createState() => _DevCompanySelectorState();
}

class _DevCompanySelectorState extends State<DevCompanySelector> {
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
    final companies = _companies;
    return ColoredBox(
      color: JitanColors.inputFill,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          JitanDimensions.pagePaddingStart,
          8,
          JitanDimensions.pagePaddingEnd,
          8,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                context.t(AdminTextKeys.devCompanySelectorLabel),
                style: JitanTextStyles.tableHeader,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            if (_failed) ...[
              Flexible(
                child: Text(
                  context.t(AdminTextKeys.devCompanySelectorLoadFailed),
                  style: JitanTextStyles.stateMessage,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(onPressed: _load, child: Text(context.t(CommonTextKeys.retry))),
            ] else if (companies == null)
              const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              DropdownButton<int>(
                isDense: true,
                value: current.company?.id,
                hint: Text(context.t(AdminTextKeys.devCompanySelectorPlaceholder), style: JitanTextStyles.inputHint),
                style: JitanTextStyles.inputText,
                underline: const SizedBox.shrink(),
                items: [
                  for (final company in companies) DropdownMenuItem(value: company.id, child: Text(company.name)),
                ],
                onChanged: (id) => current.select(companies.where((c) => c.id == id).firstOrNull),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'companies_controller.dart';
import 'companies_table.dart';

/// HR/Admin "Companies" page (Figma `Admin / Companies` 153:35,
/// `HR / Companies` 153:804).
///
/// "Add company" (Figma) is not shown yet: it arrives with the Add company
/// slice so the page never offers a button that does nothing.
class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key, required this.api, this.clock = DateTime.now});

  final CompaniesApi api;
  final DateTime Function() clock;

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  late final CompaniesController _controller = CompaniesController(widget.api)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JitanPageHeader(
          title: context.t(AdminTextKeys.companyTitle),
          subtitle: context.t(AdminTextKeys.companyListSubtitle),
        ),
        const SizedBox(height: JitanDimensions.headerToToolbar),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: JitanDimensions.filterSearchWidth),
            child: JitanFieldLabel(
              label: context.t(CommonTextKeys.searchLabel),
              child: JitanSearchField(
                clearTooltip: context.t(CommonTextKeys.searchClear),
                outlined: true,
                hintText: context.t(AdminTextKeys.companySearch),
                onChanged: _controller.updateSearch,
              ),
            ),
          ),
        ),
        const SizedBox(height: JitanDimensions.toolbarToTable),
      ],
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context, _controller.state))],
  );

  Widget _content(BuildContext context, CompaniesState state) => switch (state) {
    CompaniesLoading() => _centered(JitanLoadingState(label: context.t(AdminTextKeys.companyListLoading))),
    CompaniesFailed(:final failure) => _centered(_error(context, failure)),
    CompaniesLoaded(companies: [], search: '') => _centered(
      JitanEmptyState(
        title: context.t(AdminTextKeys.companyEmptyTitle),
        message: context.t(AdminTextKeys.companyEmptyMessage),
      ),
    ),
    CompaniesLoaded(companies: [], :final search) => _centered(
      JitanEmptyState(
        title: context.t(AdminTextKeys.companyNoMatchTitle),
        message: context.t(AdminTextKeys.companyNoMatchMessage, args: {'search': search}),
      ),
    ),
    CompaniesLoaded(:final companies) => CompaniesTable(companies: companies, now: widget.clock()),
  };

  Widget _error(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanErrorState(
      title: context.t(keys.title),
      message: context.t(keys.message),
      retryLabel: context.t(CommonTextKeys.retry),
      onRetry: _controller.load,
    );
  }

  static Widget _centered(Widget child) => JitanTableStateSliver(child: child);
}

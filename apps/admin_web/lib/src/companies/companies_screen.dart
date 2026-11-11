import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../common/api_failure_text.dart';
import '../company_context/current_company.dart';
import '../l10n/admin_text_keys.dart';
import 'add_company_dialog.dart';
import 'companies_controller.dart';
import 'companies_table.dart';
import 'company_dialog.dart';

/// HR/Admin "Companies" (Figma `1524:2`; a company `1524:105`, Add company
/// `1524:233`, just added `1524:350`, nothing yet `1524:453`). IT's database
/// starts empty, so HR adds the companies here; a company holds only its
/// name. Every change is the server's, confirmed before it shows.
class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key, required this.api, this.clock = DateTime.now});

  final CompaniesApi api;
  final DateTime Function() clock;

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  late final CompaniesController _controller = CompaniesController(widget.api)..load();
  Timer? _settle;

  /// How long a company just added stays lit up.
  static const _litFor = Duration(seconds: 3);

  @override
  void dispose() {
    _settle?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// The newest message replaces the one showing; one with an action
  /// (Add employees) still fades like the rest instead of staying.
  void _say(String text, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(text), action: action, persist: false));
  }

  /// Employees shows the company HR works in: this one, from now on.
  void _openEmployees(CompanySummary company) {
    CurrentCompanyScope.maybeOf(context)?.select(company);
    context.go(AdminRoutes.employees);
  }

  Future<void> _add() async {
    final company = await showAddCompanyDialog(context, api: widget.api, companies: _controller.loaded);
    if (company == null || !mounted) return;
    _controller.put(company, added: true);
    _settle?.cancel();
    _settle = Timer(_litFor, _controller.settle);
    _say(
      context.t(AdminTextKeys.companyAdded, args: {'name': company.name}),
      action: SnackBarAction(label: context.t(AdminTextKeys.companyAddEmployees), onPressed: () => _openEmployees(company)),
    );
  }

  Future<void> _open(CompanySummary company) async {
    final result = await showCompanyDialog(context, api: widget.api, company: company, companies: _controller.loaded);
    if (result == null || !mounted) return;
    final (change, saved) = result;
    if (change == CompanyChange.openEmployees) return _openEmployees(saved);
    _controller.put(saved);
    _say(
      context.t(switch (change) {
        CompanyChange.renamed => AdminTextKeys.companySaved,
        CompanyChange.deactivated => AdminTextKeys.companyDeactivated,
        _ => AdminTextKeys.companyReactivated,
      }, args: {'name': saved.name}),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final state = _controller.state;
      final nothingYet = state is CompaniesLoaded && state.companies.isEmpty && state.search.isEmpty;
      return JitanListPage(
        top: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JitanPageHeader(
              title: context.t(AdminTextKeys.companyTitle),
              subtitle: switch (state) {
                CompaniesLoaded(:final companies, search: '') when companies.isNotEmpty =>
                  context.tPlural(AdminTextKeys.companyCount, companies.length),
                _ => context.t(AdminTextKeys.companyListSubtitle),
              },
              action: nothingYet || state is! CompaniesLoaded
                  ? null
                  : JitanPrimaryButton(
                      label: context.t(AdminTextKeys.companyAdd),
                      icon: Icons.add,
                      height: JitanDimensions.controlHeight,
                      onPressed: _add,
                    ),
            ),
            if (!nothingYet) ...[
              const SizedBox(height: 36),
              _toolbar(context),
              const SizedBox(height: 20),
            ],
          ],
        ),
        list: [_content(context, state)],
      );
    },
  );

  Widget _toolbar(BuildContext context) {
    final search = JitanSearchField(
      clearTooltip: context.t(CommonTextKeys.searchClear),
      outlined: true,
      hintText: context.t(AdminTextKeys.companySearch),
      onChanged: _controller.updateSearch,
    );
    final pills = JitanPillSwitch<CompanyStatusFilter>(
      options: [
        (CompanyStatusFilter.all, context.t(AdminTextKeys.companyFilterAll)),
        (CompanyStatusFilter.active, context.t(CommonTextKeys.statusActive)),
        (CompanyStatusFilter.inactive, context.t(CommonTextKeys.statusInactive)),
      ],
      value: _controller.status,
      onChanged: _controller.updateStatus,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [search, pills],
            )
          : Row(
              spacing: 12,
              children: [SizedBox(width: 320, child: search), pills],
            ),
    );
  }

  Widget _content(BuildContext context, CompaniesState state) => switch (state) {
    CompaniesLoading() => _centered(JitanLoadingState(label: context.t(AdminTextKeys.companyListLoading))),
    CompaniesFailed(:final failure) => _centered(_error(context, failure)),
    // Nothing yet: calm, on the page itself, with the one thing to do.
    CompaniesLoaded(companies: [], search: '') => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 160),
        child: Column(
          spacing: 10,
          children: [
            Text(context.t(AdminTextKeys.companyEmptyTitle), style: JitanTextStyles.modalTitle.copyWith(fontSize: 22)),
            Text(
              context.t(AdminTextKeys.companyEmptyMessage),
              textAlign: TextAlign.center,
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
            const SizedBox(height: 8),
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.companyAdd),
              icon: Icons.add,
              height: JitanDimensions.controlHeight,
              onPressed: _add,
            ),
          ],
        ),
      ),
    ),
    CompaniesLoaded(companies: [], :final search) => _centered(
      JitanEmptyState(
        title: context.t(AdminTextKeys.companyNoMatchTitle),
        message: context.t(AdminTextKeys.companyNoMatchMessage, args: {'search': search}),
      ),
    ),
    CompaniesLoaded() => switch (_controller.visible) {
      [] => _centered(
        JitanEmptyState(
          title: context.t(AdminTextKeys.companyNoMatchTitle),
          message: context.t(AdminTextKeys.companyNoneWithStatus),
        ),
      ),
      final companies => CompaniesTable(
        companies: companies,
        now: widget.clock(),
        fresh: _controller.fresh,
        onOpen: _open,
        onEmployees: _openEmployees,
      ),
    },
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

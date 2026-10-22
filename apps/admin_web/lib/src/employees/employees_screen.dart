import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../common/api_failure_text.dart';
import '../company_context/company_switcher.dart';
import '../company_context/current_company.dart';
import '../l10n/admin_text_keys.dart';
import 'add_employee_dialog.dart';
import 'employees_controller.dart';
import 'employees_table.dart';
import 'manage_employee_dialog.dart';
import 'remove_employee_dialog.dart';
import 'reset_access_dialog.dart';
import 'temporary_qr/temporary_qr_dialog.dart';

/// Which employees the Status filter shows.
enum EmployeeStatusFilter { active, inactive }

/// HR/Admin "Employees" page (Figma `HR / Employees — Company switcher open`
/// 1401:2, `No company selected` 1401:121): the employees of the company
/// chosen in "Current company", with search, status filter, and each row's
/// "⋯" (Manage employee, 1399:10).
/// "Import CSV / Excel" opens Import employees for the same company.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({
    super.key,
    required this.api,
    required this.groupsApi,
    required this.companiesApi,
    required this.schedulesApi,
  });

  final EmployeesApi api;
  final GroupsApi groupsApi;
  final CompaniesApi companiesApi;
  final SchedulesApi schedulesApi;

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  EmployeesController? _controller;
  CompanySummary? _company;
  var _started = false;

  /// The list has scrolled under the fixed title and filters.
  var _listScrolled = false;

  /// The search text, owned here so it survives any rebuild of the toolbar.
  final _searchText = TextEditingController();

  /// Keeps the title and filters (their open menus, focus and text) when
  /// the page switches between a fixed header and one scroll (window height).
  final _topKey = GlobalKey();
  String _search = '';
  EmployeeStatusFilter? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final company = CurrentCompanyScope.of(context).company;
    if (_started && company?.id == _company?.id) return;
    // Another filter: a fresh list, with the search HR typed. No company
    // chosen lists every company's employees.
    _started = true;
    _company = company;
    _controller?.dispose();
    _controller = EmployeesController(widget.api, companyId: company?.id, search: _search)..load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchText.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _addEmployee() async {
    final created = await showAddEmployeeDialog(
      context,
      employeesApi: widget.api,
      groupsApi: widget.groupsApi,
      companiesApi: widget.companiesApi,
      schedulesApi: widget.schedulesApi,
    );
    if (created == null || !mounted) return;
    await _controller?.load();
    if (!mounted) return;
    final name = [created.firstName, created.lastName].whereType<String>().join(' ');
    _say(context.t(AdminTextKeys.employeeAddSuccess, args: {'name': name}));
  }

  /// "⋯" → Manage employee → the onboarding QR, or Reset account access and
  /// then the recovery QR (as in Employee details).
  ///
  /// The actions are company-scoped endpoints: the filter company, or with
  /// every company listed, one the employee belongs to (the same person and
  /// the same result in each).
  Future<void> _manage(CompanySummary? company, EmployeeSummary employee) async {
    final companyId = company?.id ?? employee.companyIds.firstOrNull;
    if (companyId == null) return;
    final action = await showManageEmployeeDialog(context, employee: employee);
    if (action == null || !mounted) return;
    if (action == EmployeeAction.remove) {
      final name = [employee.firstName, employee.lastName].whereType<String>().join(' ');
      final success = context.t(
        AdminTextKeys.employeeRemoveSuccess,
        args: {'name': name.isEmpty ? employee.code : name},
      );
      final removed = await showRemoveEmployeeDialog(
        context,
        employeesApi: widget.api,
        employee: employee,
        companyId: companyId,
      );
      if (!removed) return;
      _say(success);
      await _controller?.load();
      return;
    }
    final EmployeeDetails details;
    try {
      details = await widget.api.details(companyId, employee.id);
    } on ApiClientException catch (failure) {
      if (mounted) _say(context.t(failureTextKeysFor(failure).message));
      return;
    }
    if (!mounted) return;
    switch (action) {
      case EmployeeAction.onboardingQr:
        // After Reset account access the recovery QR applies; onboarding is
        // only for an employee who never had a password (server rule).
        await showTemporaryQrDialog(
          context,
          employeesApi: widget.api,
          employee: details,
          purpose: details.accessResetPending ? TemporaryQrPurpose.recovery : TemporaryQrPurpose.onboarding,
        );
      case EmployeeAction.resetAccess:
        final name = [details.firstName, details.lastName].whereType<String>().join(' ');
        final success = context.t(
          AdminTextKeys.employeeResetAccessSuccess,
          args: {'name': name.isEmpty ? details.code : name},
        );
        if (!await showResetAccessDialog(context, employeesApi: widget.api, employee: details)) return;
        _say(success);
        if (!mounted) return;
        await showTemporaryQrDialog(
          context,
          employeesApi: widget.api,
          employee: details,
          purpose: TemporaryQrPurpose.recovery,
        );
      case EmployeeAction.remove:
        // Handled above: it needs no details.
        return;
    }
    await _controller?.load();
  }

  @override
  Widget build(BuildContext context) {
    final company = _company;
    final controller = _controller;
    final padding = JitanDimensions.pagePadding(MediaQuery.sizeOf(context).width);
    final top = Column(
      key: _topKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JitanPageHeader(
          title: context.t(AdminTextKeys.employeeTitle),
          subtitle: context.t(AdminTextKeys.employeeListSubtitle),
          action: Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              JitanOutlineButton(
                label: context.t(AdminTextKeys.employeeImportAction),
                height: JitanDimensions.controlHeight,
                // The company is chosen on the Import page; the filter is only a filter.
                onPressed: () => context.go(AdminRoutes.employeeImport),
              ),
              JitanPrimaryButton(
                label: context.t(AdminTextKeys.employeeAddAction),
                icon: Icons.add,
                height: JitanDimensions.controlHeight,
                // The company is chosen in the wizard; the filter is only a filter.
                onPressed: _addEmployee,
              ),
            ],
          ),
        ),
        const SizedBox(height: JitanDimensions.headerToToolbar),
        _toolbar(context),
        const SizedBox(height: 28),
        Text(context.t(AdminTextKeys.employeeSection), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
        const SizedBox(height: 16),
      ],
    );
    final list = [
      if (controller != null)
        ListenableBuilder(listenable: controller, builder: (context, _) => _content(context, company, controller)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // As in Linear, Notion or Stripe: title, actions and filters stay in
        // place and only the list scrolls, its heading row pinned. On a phone
        // or a short window they would leave too little room for the list,
        // so there the whole page scrolls.
        // Decided from the window, which stays the same while a field gains
        // or loses focus (the page's own height may briefly change then).
        final window = MediaQuery.sizeOf(context);
        final fixedTop = constraints.maxWidth >= JitanDimensions.phoneBreakpoint && window.height >= _fixedTopMinHeight;
        if (!fixedTop) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: padding,
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(child: top),
                    ...list,
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: padding.copyWith(bottom: 0), child: top),
            // A soft line once rows pass under the fixed part.
            AnimatedOpacity(
              opacity: _listScrolled ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Container(height: 1, color: JitanColors.inputBorder),
            ),
            Expanded(
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (notification) {
                  final scrolled = notification.metrics.pixels > 0;
                  if (notification.depth == 0 && scrolled != _listScrolled) setState(() => _listScrolled = scrolled);
                  return false;
                },
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: padding.copyWith(top: 0),
                      sliver: SliverMainAxisGroup(slivers: list),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Below this window height the title and filters scroll with the list.
  static const _fixedTopMinHeight = 640.0;

  Widget _toolbar(BuildContext context) {
    final search = JitanFieldLabel(
      label: context.t(CommonTextKeys.searchLabel),
      child: JitanSearchField(
        controller: _searchText,
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        hintText: context.t(AdminTextKeys.employeeSearch),
        onChanged: (text) {
          _search = text;
          _controller?.updateSearch(text);
        },
      ),
    );
    final status = JitanSelectField<EmployeeStatusFilter?>(
      label: context.t(AdminTextKeys.employeeFilterStatus),
      value: _status,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.employeeFilterStatusAll)),
        JitanSelectOption(value: EmployeeStatusFilter.active, label: context.t(CommonTextKeys.statusActive)),
        JitanSelectOption(value: EmployeeStatusFilter.inactive, label: context.t(CommonTextKeys.statusInactive)),
      ],
      onChanged: (value) => setState(() => _status = value),
    );
    final switcher = CompanySwitcher(companiesApi: widget.companiesApi);
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 14), status, const SizedBox(height: 14), switcher],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(flex: 330, child: search),
                const SizedBox(width: 20),
                Flexible(flex: 220, child: status),
                const SizedBox(width: 64),
                Flexible(flex: 255, child: switcher),
                const Spacer(flex: 215),
              ],
            ),
    );
  }

  Widget _content(BuildContext context, CompanySummary? company, EmployeesController controller) =>
      switch (controller.state) {
        EmployeesLoading() => _centered(JitanLoadingState(label: context.t(AdminTextKeys.employeeListLoading))),
        EmployeesFailed(:final failure) => _centered(_error(context, failure, controller)),
        EmployeesLoaded(employees: [], search: '') => _centered(
          JitanEmptyState(
            title: context.t(AdminTextKeys.employeeEmptyTitle),
            message: company == null
                ? context.t(AdminTextKeys.employeeEmptyMessageAll)
                : context.t(AdminTextKeys.employeeEmptyMessage, args: {'company': company.name}),
          ),
        ),
        EmployeesLoaded(:final employees) => switch ([
          for (final e in employees)
            if (_status == null || e.isActive == (_status == EmployeeStatusFilter.active)) e,
        ]) {
          [] => _centered(
            JitanEmptyState(
              title: context.t(AdminTextKeys.employeeNoMatchTitle),
              message: context.t(AdminTextKeys.employeeNoMatch),
            ),
          ),
          final visible => EmployeesTable(
            employees: visible,
            total: employees.length,
            onManage: (employee) => _manage(company, employee),
          ),
        },
      };

  Widget _error(BuildContext context, ApiClientException failure, EmployeesController controller) {
    final keys = failureTextKeysFor(failure);
    return JitanErrorState(
      title: context.t(keys.title),
      message: context.t(keys.message),
      retryLabel: context.t(CommonTextKeys.retry),
      onRetry: controller.load,
    );
  }

  /// A loading, empty or error state in the table card.
  static Widget _centered(Widget child) => SliverToBoxAdapter(
    child: JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      child: SizedBox(height: JitanDimensions.tableStateHeight, child: child),
    ),
  );
}

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
import 'assignments/manage_assignments_dialog.dart';
import 'employee_dialog.dart';
import 'employee_standing.dart';
import 'employees_controller.dart';
import 'employees_table.dart';
import 'remove_employee_dialog.dart';
import 'reset_access_dialog.dart';
import 'temporary_qr/temporary_qr_dialog.dart';

/// HR/Admin "Employees" page (Figma `1531:2`): the employees of the company
/// chosen on the right ("All companies" or one), with search and the status
/// buttons. A row opens the employee (`1531:259`, not set up `1531:459`).
/// "Import CSV / Excel" opens Import employees.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({
    super.key,
    required this.api,
    required this.groupsApi,
    required this.companiesApi,
    required this.schedulesApi,
    required this.assignmentsApi,
    this.status,
  });

  final EmployeesApi api;
  final GroupsApi groupsApi;
  final CompaniesApi companiesApi;
  final SchedulesApi schedulesApi;
  final EmployeeAssignmentsApi assignmentsApi;

  /// Opened from the Dashboard: the status filter at first.
  final EmployeeStatusFilter? status;

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  EmployeesController? _controller;
  CompanySummary? _company;
  var _started = false;

  /// The search text, owned here so it survives any rebuild of the toolbar.
  final _searchText = TextEditingController();

  String _search = '';
  late EmployeeStatusFilter _status = widget.status ?? EmployeeStatusFilter.all;

  /// Every company, to name an employee's in their pop-up.
  List<CompanySummary> _companies = const [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await widget.companiesApi.listCompanies();
      if (mounted) _companies = companies;
    } on ApiClientException {
      // Only the names in a pop-up depend on it; they show "—" without.
    }
  }

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

  void _say(String text) => showJitanToast(context, text);

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

  /// A row: the employee's pop-up, then what HR chose there.
  ///
  /// The actions are company-scoped endpoints: the filter company, or with
  /// every company listed, one the employee belongs to (the same person and
  /// the same result in each).
  Future<void> _open(CompanySummary? company, EmployeeSummary employee) async {
    final companyId = company?.id ?? employee.companyIds.firstOrNull;
    if (companyId == null) return;
    final result = await showEmployeeDialog(
      context,
      api: widget.api,
      employee: employee,
      companyId: companyId,
      companies: _companies,
    );
    if (result == null || !mounted) return;
    final (choice, details) = result;
    final name = [details.firstName, details.lastName].whereType<String>().join(' ');
    final who = name.isEmpty ? details.code : name;
    switch (choice) {
      case EmployeeChoice.assignments:
        final saved = context.t(AdminTextKeys.assignmentsSaved);
        if (!await showManageAssignmentsDialog(context, api: widget.assignmentsApi, employee: details)) return;
        _say(saved);
      case EmployeeChoice.setUpQr:
        // After Reset account access the recovery QR applies; onboarding is
        // only for an employee who never had a password (server rule).
        await showTemporaryQrDialog(
          context,
          employeesApi: widget.api,
          employee: details,
          purpose: details.accessResetPending ? TemporaryQrPurpose.recovery : TemporaryQrPurpose.onboarding,
        );
      case EmployeeChoice.resetAccess:
        final success = context.t(AdminTextKeys.employeeResetAccessSuccess, args: {'name': who});
        if (!await showResetAccessDialog(context, employeesApi: widget.api, employee: details)) return;
        _say(success);
        if (!mounted) return;
        // Figma 207:6: after the reset, HR/Admin shows the recovery QR.
        await showTemporaryQrDialog(
          context,
          employeesApi: widget.api,
          employee: details,
          purpose: TemporaryQrPurpose.recovery,
        );
      case EmployeeChoice.remove:
        final success = context.t(AdminTextKeys.employeeRemoveSuccess, args: {'name': who});
        if (!await showRemoveEmployeeDialog(context, employeesApi: widget.api, employee: employee, companyId: companyId)) {
          return;
        }
        _say(success);
    }
    await _controller?.load();
  }

  @override
  Widget build(BuildContext context) {
    final company = _company;
    final controller = _controller;
    // Rebuilt with the list, so the count under the title follows it.
    Widget top() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JitanPageHeader(
          title: context.t(AdminTextKeys.employeeTitle),
          subtitle: switch (controller?.state) {
            EmployeesLoaded(:final employees, search: '') when employees.isNotEmpty =>
              context.tPlural(AdminTextKeys.employeeCount, employees.length),
            _ => context.t(AdminTextKeys.employeeListSubtitle),
          },
          action: Wrap(
            spacing: 12,
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
        const SizedBox(height: JitanDimensions.toolbarToTable),
      ],
    );
    return JitanListPage(
      top: controller == null ? top() : ListenableBuilder(listenable: controller, builder: (context, _) => top()),
      list: [
        if (controller != null)
          ListenableBuilder(listenable: controller, builder: (context, _) => _content(context, company, controller)),
      ],
    );
  }

  /// The narrowest width that holds the toolbar on one row.
  static const _toolbarRowWidth = 760.0;

  Widget _toolbar(BuildContext context) {
    final search = JitanSearchField(
      controller: _searchText,
      clearTooltip: context.t(CommonTextKeys.searchClear),
      outlined: true,
      hintText: context.t(AdminTextKeys.employeeSearch),
      onChanged: (text) {
        _search = text;
        _controller?.updateSearch(text);
      },
    );
    final status = JitanPillSwitch<EmployeeStatusFilter>(
      options: [
        (EmployeeStatusFilter.all, context.t(AdminTextKeys.employeeFilterAll)),
        (EmployeeStatusFilter.active, context.t(CommonTextKeys.statusActive)),
        (EmployeeStatusFilter.notSetUp, context.t(AdminTextKeys.employeeNotSetUp)),
        (EmployeeStatusFilter.inactive, context.t(CommonTextKeys.statusInactive)),
      ],
      value: _status,
      onChanged: (value) => setState(() => _status = value),
    );
    final switcher = CompanySwitcher(companiesApi: widget.companiesApi);
    return LayoutBuilder(
      // One row needs the search, the four buttons and the company side by
      // side; narrower, they stack.
      builder: (context, constraints) => constraints.maxWidth < _toolbarRowWidth
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [search, Align(alignment: Alignment.centerLeft, child: status), switcher],
            )
          : Row(
              spacing: 12,
              children: [
                Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: search)),
                status,
                const Spacer(),
                SizedBox(width: 220, child: switcher),
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
            if (_status.lets(e)) e,
        ]) {
          [] => _centered(
            JitanEmptyState(
              title: context.t(AdminTextKeys.employeeNoMatchTitle),
              message: context.t(AdminTextKeys.employeeNoMatch),
            ),
          ),
          final visible => EmployeesTable(employees: visible, onOpen: (employee) => _open(company, employee)),
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

  static Widget _centered(Widget child) => JitanTableStateSliver(child: child);
}

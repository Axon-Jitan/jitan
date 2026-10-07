import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../company_context/current_company.dart';
import '../l10n/admin_text_keys.dart';
import 'employees_controller.dart';
import 'employees_table.dart';

/// HR/Admin "Employees" page for the current company (Figma
/// `Admin / Employees` 153:137, `HR / Employees` 153:906).
///
/// "Import CSV / Excel" and "Add employee" (Figma) arrive with EMP-02 so the
/// page never offers a button that does nothing.
class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key, required this.api});

  final EmployeesApi api;

  @override
  Widget build(BuildContext context) {
    final company = CurrentCompanyScope.of(context).company;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        JitanDimensions.pagePaddingStart,
        JitanDimensions.pagePaddingVertical,
        JitanDimensions.pagePaddingEnd,
        JitanDimensions.pagePaddingVertical,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanPageHeader(
            title: context.t(AdminTextKeys.employeeTitle),
            subtitle: context.t(AdminTextKeys.employeeListSubtitle),
          ),
          const SizedBox(height: JitanDimensions.headerToToolbar),
          if (company == null)
            JitanSurfaceCard(
              radius: JitanDimensions.tableCardRadius,
              child: SizedBox(
                height: JitanDimensions.tableMinHeight,
                child: JitanEmptyState(
                  title: context.t(AdminTextKeys.employeeNoCompanyTitle),
                  message: context.t(AdminTextKeys.employeeNoCompanyMessage),
                ),
              ),
            )
          else
            // Keyed by company: switching company starts a fresh list.
            _CompanyEmployees(key: ValueKey(company.id), api: api, company: company),
        ],
      ),
    );
  }
}

class _CompanyEmployees extends StatefulWidget {
  const _CompanyEmployees({super.key, required this.api, required this.company});

  final EmployeesApi api;
  final CompanySummary company;

  @override
  State<_CompanyEmployees> createState() => _CompanyEmployeesState();
}

class _CompanyEmployeesState extends State<_CompanyEmployees> {
  late final EmployeesController _controller =
      EmployeesController(widget.api, companyId: widget.company.id)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanSurfaceCard(
            radius: JitanDimensions.toolbarCardRadius,
            padding: const EdgeInsets.all(JitanDimensions.toolbarPadding),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: JitanDimensions.searchFieldWidth),
                child: JitanSearchField(
                  hintText: context.t(AdminTextKeys.employeeSearch),
                  onChanged: _controller.updateSearch,
                ),
              ),
            ),
          ),
          const SizedBox(height: JitanDimensions.toolbarToTable),
          JitanSurfaceCard(
            radius: JitanDimensions.tableCardRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: JitanDimensions.tableMinHeight),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _content(context, _controller.state),
              ),
            ),
          ),
        ],
      );

  Widget _content(BuildContext context, EmployeesState state) => switch (state) {
        EmployeesLoading() => _centered(JitanLoadingState(label: context.t(AdminTextKeys.employeeListLoading))),
        EmployeesFailed(:final failure) => _centered(_error(context, failure)),
        EmployeesLoaded(employees: [], search: '') => _centered(
            JitanEmptyState(
              title: context.t(AdminTextKeys.employeeEmptyTitle),
              message: context.t(AdminTextKeys.employeeEmptyMessage, args: {'company': widget.company.name}),
            ),
          ),
        EmployeesLoaded(employees: [], :final search) => _centered(
            JitanEmptyState(
              title: context.t(AdminTextKeys.employeeNoMatchTitle),
              message: context.t(AdminTextKeys.employeeNoMatchMessage, args: {'search': search}),
            ),
          ),
        EmployeesLoaded(:final employees) => EmployeesTable(employees: employees),
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

  static Widget _centered(Widget child) => SizedBox(height: JitanDimensions.tableMinHeight, child: child);
}

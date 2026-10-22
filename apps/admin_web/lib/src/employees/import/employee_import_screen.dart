import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../app/admin_routes.dart';
import '../../l10n/admin_text_keys.dart';
import 'employee_import_controller.dart';
import 'employee_import_file.dart';
import 'employee_import_preview.dart';
import 'employee_import_text.dart';
import 'employee_import_upload.dart';
import 'platform/file_download.dart';
import 'platform/import_file_picker.dart';

/// HR/Admin "Import employees" (Figma `1419:2` … `1419:404`), opened from
/// Employees → "Import CSV / Excel": many employees at once, from an Excel
/// or CSV file, into the company HR chooses here. The Employees "Current
/// company" only filters the list and never chooses for an import (product
/// owner, 2026-10-21).
class EmployeeImportScreen extends StatefulWidget {
  const EmployeeImportScreen({
    super.key,
    required this.api,
    required this.companiesApi,
    this.chooseFile = chooseImportFile,
    this.download = downloadFile,
  });

  final EmployeesApi api;
  final CompaniesApi companiesApi;
  final ChooseImportFile chooseFile;
  final DownloadFile download;

  @override
  State<EmployeeImportScreen> createState() => _EmployeeImportScreenState();
}

class _EmployeeImportScreenState extends State<EmployeeImportScreen> {
  List<CompanySummary>? _companies;
  bool _companiesFailed = false;
  CompanySummary? _company;
  EmployeeImportController? _controller;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Loads the companies; [retry] after a failure shows the field loading.
  Future<void> _loadCompanies({bool retry = false}) async {
    if (retry) setState(() => _companiesFailed = false);
    try {
      final companies = await widget.companiesApi.listCompanies();
      if (mounted) setState(() => _companies = companies);
    } on ApiClientException {
      if (mounted) setState(() => _companiesFailed = true);
    }
  }

  /// Another company: start again, so no file is imported into the wrong one.
  void _selectCompany(int? id) {
    final company = _companies?.where((c) => c.id == id).firstOrNull;
    if (company?.id == _company?.id) return;
    setState(() {
      _company = company;
      _controller?.dispose();
      _controller = company == null
          ? null
          : EmployeeImportController(widget.api, companyId: company.id, columnNames: EmployeeImportText.columnNames(context));
    });
  }

  Future<void> _choose() async {
    final file = await widget.chooseFile();
    if (file == null || !mounted) return;
    await _controller?.open(file.name, file.bytes);
  }

  void _downloadTemplate() {
    final titles = [for (final column in ImportColumn.values) context.t(EmployeeImportText.columnKey(column))];
    widget.download(
      context.t(AdminTextKeys.employeeImportTemplateFile),
      EmployeeImportFileReader.template(titles),
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return SingleChildScrollView(
      padding: JitanDimensions.pagePadding(MediaQuery.sizeOf(context).width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go(AdminRoutes.employees),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
              child: Text(context.t(AdminTextKeys.employeeImportBack), style: JitanTextStyles.fieldLabel),
            ),
          ),
          const SizedBox(height: 4),
          JitanPageHeader(
            title: context.t(AdminTextKeys.employeeImportTitle),
            subtitle: context.t(AdminTextKeys.employeeImportSubtitle),
          ),
          const SizedBox(height: 28),
          if (controller == null)
            ..._beforeCompany(context)
          else
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => switch (controller.state) {
                ImportDone(:final result) => EmployeeImportDone(
                  result: result,
                  companyName: _company!.name,
                  onBack: () => context.go(AdminRoutes.employees),
                  onAgain: controller.reset,
                ),
                final state => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fixed while a file is read or imported.
                    _companyField(
                      context,
                      enabled: !(state is ImportReading || state is ImportPreview && state.importing),
                    ),
                    const SizedBox(height: 20),
                    if (state is ImportPreview)
                      EmployeeImportPreview(state: state, onImport: controller.import, onChooseAnother: _choose)
                    else ...[
                      EmployeeImportUpload(
                        state: state,
                        onChoose: _choose,
                        onDropped: (file) => controller.open(file.name, file.bytes),
                      ),
                      const SizedBox(height: 20),
                      EmployeeImportColumnsCard(onDownloadTemplate: _downloadTemplate),
                    ],
                  ],
                ),
              },
            ),
        ],
      ),
    );
  }

  /// No company yet: the field, and the upload card waiting for it.
  List<Widget> _beforeCompany(BuildContext context) => [
    _companyField(context, enabled: true),
    const SizedBox(height: 20),
    const EmployeeImportUpload(state: ImportWaitingForFile(), onChoose: null, onDropped: null),
    const SizedBox(height: 20),
    EmployeeImportColumnsCard(onDownloadTemplate: _downloadTemplate),
  ];

  /// "Company" (Figma `Select / Company`): where the employees are added.
  Widget _companyField(BuildContext context, {required bool enabled}) {
    final companies = _companies;
    final field = JitanSelectField<int>(
      label: context.t(AdminTextKeys.employeeImportCompany),
      hintText: context.t(
        _companiesFailed ? AdminTextKeys.employeeFilterCompanyFailed : AdminTextKeys.employeeFilterCompanyHint,
      ),
      value: _company?.id,
      options: [for (final company in companies ?? const <CompanySummary>[]) JitanSelectOption(value: company.id, label: company.name)],
      onChanged: _companiesFailed
          ? (_) => _loadCompanies(retry: true)
          : companies == null || !enabled
          ? null
          : _selectCompany,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 330), child: field),
    );
  }
}

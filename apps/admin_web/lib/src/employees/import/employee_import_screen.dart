import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../app/admin_routes.dart';
import '../../company_context/current_company.dart';
import '../../l10n/admin_text_keys.dart';
import 'employee_import_controller.dart';
import 'employee_import_file.dart';
import 'employee_import_preview.dart';
import 'employee_import_text.dart';
import 'employee_import_upload.dart';
import 'platform/file_download.dart';
import 'platform/import_file_picker.dart';

/// HR/Admin "Import employees" (Figma `1419:2` … `1419:404`), opened from
/// Employees → "Import CSV / Excel": many employees of the current company
/// at once, from an Excel or CSV file.
class EmployeeImportScreen extends StatefulWidget {
  const EmployeeImportScreen({
    super.key,
    required this.api,
    this.chooseFile = chooseImportFile,
    this.download = downloadFile,
  });

  final EmployeesApi api;
  final ChooseImportFile chooseFile;
  final DownloadFile download;

  @override
  State<EmployeeImportScreen> createState() => _EmployeeImportScreenState();
}

class _EmployeeImportScreenState extends State<EmployeeImportScreen> {
  EmployeeImportController? _controller;
  CompanySummary? _company;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final company = CurrentCompanyScope.of(context).company;
    if (company?.id == _company?.id) return;
    // Another company: start again, so no file is imported into the wrong one.
    _company = company;
    _controller?.dispose();
    _controller = company == null
        ? null
        : EmployeeImportController(
            widget.api,
            companyId: company.id,
            columnNames: EmployeeImportText.columnNames(context),
          );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
    final company = _company;
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
            // Without a company (e.g. the page was reloaded) there is nothing
            // to import into: HR picks one on Employees.
            subtitle: company == null
                ? context.t(AdminTextKeys.employeeNoCompany)
                : context.t(AdminTextKeys.employeeImportSubtitle, args: {'company': company.name}),
          ),
          const SizedBox(height: 28),
          if (company != null && controller != null)
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => switch (controller.state) {
                final ImportPreview preview => EmployeeImportPreview(
                  state: preview,
                  onImport: controller.import,
                  onChooseAnother: _choose,
                ),
                ImportDone(:final result) => EmployeeImportDone(
                  result: result,
                  companyName: company.name,
                  onBack: () => context.go(AdminRoutes.employees),
                  onAgain: controller.reset,
                ),
                final state => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EmployeeImportUpload(
                      state: state,
                      onChoose: _choose,
                      onDropped: (file) => controller.open(file.name, file.bytes),
                    ),
                    const SizedBox(height: 20),
                    EmployeeImportColumnsCard(onDownloadTemplate: _downloadTemplate),
                  ],
                ),
              },
            ),
        ],
      ),
    );
  }
}

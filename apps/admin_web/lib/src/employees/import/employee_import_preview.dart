import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import 'employee_import_controller.dart';
import 'employee_import_text.dart';
import 'employee_import_upload.dart';

/// "Preview" and "Importing" (Figma `1419:149`, `1419:259`, phone
/// `1419:404`): how many rows are ready, every row with its status, and the
/// import button. Rows with problems are skipped.
class EmployeeImportPreview extends StatelessWidget {
  const EmployeeImportPreview({super.key, required this.state, required this.onImport, required this.onChooseAnother});

  final ImportPreview state;
  final VoidCallback onImport;
  final VoidCallback onChooseAnother;

  /// Rows the table shows before it scrolls (Figma: 7).
  static const visibleRows = 7;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final phone = constraints.maxWidth < JitanDimensions.phoneBreakpoint;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summary(context, phone: phone),
          SizedBox(height: phone ? 16 : 24),
          if (phone) ..._cards(context) else _table(context),
          SizedBox(height: phone ? 8 : 24),
          _actions(context, phone: phone),
        ],
      );
    },
  );

  Widget _summary(BuildContext context, {required bool phone}) {
    final file = state.file;
    final chip = ImportFileChip(
      name: file.name,
      details: context.tPlural(
        AdminTextKeys.employeeImportFileRows,
        file.rows.length,
        args: {'size': EmployeeImportText.size(context, file.sizeBytes)},
      ),
      trailing: state.importing
          ? null
          : TextButton(
              onPressed: onChooseAnother,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              child: Text(
                context.t(AdminTextKeys.employeeImportChange),
                style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13, color: JitanColors.vermilion),
              ),
            ),
    );
    final problems = state.problems.length;
    final stats = [
      (file.rows.length, context.tPlural(AdminTextKeys.employeeImportSummaryRows, file.rows.length), JitanColors.ink),
      (state.readyCount, context.t(AdminTextKeys.employeeImportSummaryReady), JitanColors.ink),
      (problems, context.tPlural(AdminTextKeys.employeeImportSummaryProblems, problems), problems == 0 ? JitanColors.ink : JitanColors.errorStrong),
    ];
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            [for (final (count, label, _) in stats) '$count $label'].join(' · '),
            style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          chip,
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 16,
      children: [
        // Each figure stays whole; on a narrow window they wrap.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            for (final (index, (count, label, color)) in stats.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0)
                    Container(width: 1, height: 27, margin: const EdgeInsets.symmetric(horizontal: 22), color: JitanColors.inputBorder),
                  Text('$count', style: JitanTextStyles.pageTitle.copyWith(fontSize: 24, color: color)),
                  const SizedBox(width: 8),
                  Text(label, style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
                ],
              ),
          ],
        ),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: chip),
      ],
    );
  }

  Widget _status(BuildContext context, EmployeeImportRow row) {
    final problem = state.problems[row.row];
    return problem == null
        ? Text(context.t(AdminTextKeys.employeeImportReady), style: JitanTextStyles.tableCell.copyWith(color: JitanColors.success))
        : Text(
            EmployeeImportText.problem(context, problem),
            style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.errorStrong),
          );
  }

  static String _or(String? value) => value == null || value.isEmpty ? '—' : value;

  Widget _table(BuildContext context) {
    final rows = state.file.rows;
    final muted = JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted);
    Widget cell(String? value, {bool strong = false}) => Text(
      _or(value),
      style: value == null || value.isEmpty ? muted : (strong ? JitanTextStyles.tableCellStrong : JitanTextStyles.tableCell),
    );
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanDataTable(
            columns: [
              JitanTableColumn(label: context.t(AdminTextKeys.employeeImportTableRow), flex: 7),
              JitanTableColumn(label: context.t(AdminTextKeys.employeeImportColumnFirstName), flex: 15),
              JitanTableColumn(label: context.t(AdminTextKeys.employeeImportColumnLastName), flex: 15),
              JitanTableColumn(label: context.t(AdminTextKeys.employeeImportTableCode), flex: 11),
              JitanTableColumn(label: context.t(AdminTextKeys.employeeImportColumnGroups), flex: 19),
              JitanTableColumn(label: context.t(AdminTextKeys.employeeImportColumnPhone), flex: 18),
              JitanTableColumn(label: context.t(AdminTextKeys.employeeImportTableStatus), flex: 23),
            ],
            rows: [
              for (final row in rows)
                [
                  Text('${row.row}', style: muted),
                  cell(row.firstName, strong: true),
                  cell(row.lastName),
                  cell(row.code),
                  cell(row.groups.join('; ')),
                  cell(row.phone),
                  _status(context, row),
                ],
            ],
            maxHeight: JitanDimensions.tableHeaderHeight + visibleRows * JitanDimensions.tableRowHeight,
            rowColor: (index) => state.problems.containsKey(rows[index].row) ? JitanColors.errorSurface : null,
          ),
          if (rows.length > visibleRows)
            Padding(
              padding: const EdgeInsets.fromLTRB(JitanDimensions.tableHorizontalPadding, 14, JitanDimensions.tableHorizontalPadding, 16),
              child: Text(
                context.t(AdminTextKeys.employeeImportTableMore, args: {'shown': visibleRows, 'total': rows.length}),
                style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  /// On a phone each row is a card (Figma `1419:404`).
  List<Widget> _cards(BuildContext context) => [
    for (final row in state.file.rows)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: state.problems.containsKey(row.row) ? JitanColors.errorSurface : JitanColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: JitanColors.inputBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [row.firstName, row.lastName].where((s) => s.isNotEmpty).join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JitanTextStyles.tableCellStrong,
                    ),
                  ),
                  Text(
                    context.t(AdminTextKeys.employeeImportRowLabel, args: {'row': row.row}),
                    style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [_or(row.code), if (row.groups.isNotEmpty) row.groups.join('; ')].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 4),
              DefaultTextStyle.merge(style: const TextStyle(fontSize: 13), child: _status(context, row)),
            ],
          ),
        ),
      ),
  ];

  Widget _actions(BuildContext context, {required bool phone}) {
    final failure = state.failure;
    final note = Text(
      failure == null ? context.t(AdminTextKeys.employeeImportNote) : context.t(failureTextKeysFor(failure).message),
      style: JitanTextStyles.stateMessage.copyWith(fontSize: 13, color: failure == null ? null : JitanColors.errorStrong),
    );
    final ready = state.readyCount;
    final import = JitanPrimaryButton(
      label: context.tPlural(state.importing ? AdminTextKeys.employeeImportImporting : AdminTextKeys.employeeImportSubmit, ready),
      onPressed: state.importing || ready == 0 ? null : onImport,
    );
    final another = JitanOutlineButton(
      label: context.t(AdminTextKeys.employeeImportChooseAnother),
      onPressed: state.importing ? null : onChooseAnother,
    );
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [note, const SizedBox(height: 16), import, const SizedBox(height: 10), another],
      );
    }
    return JitanSurfaceCard(
      radius: JitanDimensions.toolbarCardRadius,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 760
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  note,
                  const SizedBox(height: 14),
                  Wrap(spacing: 12, runSpacing: 10, children: [another, import]),
                ],
              )
            : Row(
                children: [
                  Expanded(child: note),
                  const SizedBox(width: 20),
                  another,
                  const SizedBox(width: 12),
                  ConstrainedBox(constraints: const BoxConstraints(minWidth: 200), child: import),
                ],
              ),
      ),
    );
  }
}

/// "Done" (Figma `1419:369`): how many employees the server added.
class EmployeeImportDone extends StatelessWidget {
  const EmployeeImportDone({
    super.key,
    required this.result,
    required this.companyName,
    required this.onBack,
    required this.onAgain,
  });

  final EmployeeImportResult result;
  final String companyName;
  final VoidCallback onBack;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final skipped = result.skipped.length;
    final message = [
      if (skipped > 0) context.tPlural(AdminTextKeys.employeeImportDoneSkipped, skipped),
      context.t(AdminTextKeys.employeeImportDoneOnboarding),
    ].join(' ');
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: JitanColors.successSurface, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: JitanColors.success, size: 24),
          ),
          const SizedBox(height: 20),
          Text(
            context.tPlural(AdminTextKeys.employeeImportDoneTitle, result.added, args: {'company': companyName}),
            textAlign: TextAlign.center,
            style: JitanTextStyles.stateTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: JitanTextStyles.stateMessage.copyWith(fontSize: 14)),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              JitanOutlineButton(label: context.t(AdminTextKeys.employeeImportDoneAgain), onPressed: onAgain),
              JitanPrimaryButton(label: context.t(AdminTextKeys.employeeImportDoneBack), onPressed: onBack),
            ],
          ),
        ],
      ),
    );
  }
}

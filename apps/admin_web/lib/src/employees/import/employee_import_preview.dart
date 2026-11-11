import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../common/api_failure_text.dart';
import '../../l10n/admin_text_keys.dart';
import 'employee_import_controller.dart';
import 'employee_import_text.dart';
import 'employee_import_upload.dart';

/// "Preview" and "Importing" (Figma `1538:2`): the file with Change, how
/// many rows are ready and how many have problems, every row with all its
/// problems, and the import button. Rows with problems are skipped.
class EmployeeImportPreview extends StatelessWidget {
  const EmployeeImportPreview({super.key, required this.state, required this.onImport, required this.onChooseAnother});

  final ImportPreview state;
  final VoidCallback onImport;
  final VoidCallback onChooseAnother;

  /// Rows the table shows before it scrolls.
  static const visibleRows = 7;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final phone = constraints.maxWidth < JitanDimensions.phoneBreakpoint;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summary(context),
          const SizedBox(height: 20),
          if (phone) ..._cards(context) else _table(context),
          const SizedBox(height: 20),
          _actions(context, phone: phone),
        ],
      );
    },
  );

  /// The file with its one Change, and "2 ready · 3 with problems".
  Widget _summary(BuildContext context) {
    final file = state.file;
    final problems = state.problems.length;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ImportFileChip(
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
                    style: TextButton.styleFrom(foregroundColor: JitanColors.ink, padding: const EdgeInsets.symmetric(horizontal: 6)),
                    child: Text(context.t(AdminTextKeys.employeeImportChange), style: JitanTextStyles.tableCellStrong),
                  ),
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: context.tPlural(AdminTextKeys.employeeImportReadyCount, state.readyCount),
                style: const TextStyle(color: JitanColors.success),
              ),
              if (problems > 0) ...[
                const TextSpan(text: '  ·  ', style: TextStyle(color: JitanColors.inkMuted)),
                TextSpan(
                  text: context.tPlural(AdminTextKeys.employeeImportProblemCount, problems),
                  style: const TextStyle(color: JitanColors.errorStrong),
                ),
              ],
            ],
          ),
          style: JitanTextStyles.tableCellStrong,
        ),
      ],
    );
  }

  /// Ready, or every problem of the row, one per line.
  Widget _status(BuildContext context, EmployeeImportRow row) {
    final problems = state.problems[row.row];
    if (problems == null) {
      return Text(context.t(AdminTextKeys.employeeImportReady), style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.success));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        for (final problem in problems)
          Text(EmployeeImportText.problem(context, problem), style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.errorStrong)),
      ],
    );
  }

  static String _or(String? value) => value == null || value.isEmpty ? '—' : value;

  Widget _table(BuildContext context) {
    final rows = state.file.rows;
    final muted = JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted);
    Widget cell(String? value, {bool strong = false}) => Text(
      _or(value),
      overflow: TextOverflow.ellipsis,
      style: value == null || value.isEmpty ? muted : (strong ? JitanTextStyles.tableCellStrong : JitanTextStyles.tableCell),
    );
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      child: JitanDataTable(
        columns: [
          JitanTableColumn(label: context.t(AdminTextKeys.employeeImportTableRow), flex: 6),
          JitanTableColumn(label: context.t(AdminTextKeys.employeeImportColumnFirstName), flex: 12),
          JitanTableColumn(label: context.t(AdminTextKeys.employeeImportColumnLastName), flex: 13),
          JitanTableColumn(label: context.t(AdminTextKeys.employeeImportTableCode), flex: 9),
          JitanTableColumn(label: context.t(AdminTextKeys.employeeImportColumnPhone), flex: 16),
          JitanTableColumn(label: context.t(AdminTextKeys.employeeImportColumnEmail), flex: 20),
          JitanTableColumn(label: context.t(AdminTextKeys.employeeImportColumnGroups), flex: 14),
          JitanTableColumn(label: '', flex: 20),
        ],
        rows: [
          for (final row in rows)
            [
              Text('${row.row}', style: muted),
              cell(row.firstName, strong: true),
              cell(row.lastName),
              cell(row.code),
              cell(row.phone),
              cell(row.email),
              cell(row.groups.join('; ')),
              _status(context, row),
            ],
        ],
        maxHeight: JitanDimensions.tableHeaderHeight + visibleRows * (JitanDimensions.tableRowHeight + 8),
      ),
    );
  }

  /// On a phone each row is a card.
  List<Widget> _cards(BuildContext context) => [
    for (final row in state.file.rows)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: JitanColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: JitanColors.cardBorder),
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

  /// One quiet line and the import button; no second way to change the file.
  Widget _actions(BuildContext context, {required bool phone}) {
    final failure = state.failure;
    final note = Text(
      failure == null ? context.t(AdminTextKeys.employeeImportNote) : context.t(failureTextKeysFor(failure).message),
      style: JitanTextStyles.tableCell.copyWith(color: failure == null ? JitanColors.inkMuted : JitanColors.errorStrong),
    );
    final ready = state.readyCount;
    final import = JitanPrimaryButton(
      label: context.tPlural(state.importing ? AdminTextKeys.employeeImportImporting : AdminTextKeys.employeeImportSubmit, ready),
      onPressed: state.importing || ready == 0 ? null : onImport,
    );
    if (phone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [note, import]);
    }
    return Row(children: [Expanded(child: note), const SizedBox(width: 20), import]);
  }
}

/// "Done" (Figma `1538:273`): on the page itself, no card. How many were
/// added, the skipped rows to download, one Done, and a quiet way to import
/// another file.
class EmployeeImportDone extends StatelessWidget {
  const EmployeeImportDone({
    super.key,
    required this.state,
    required this.companyName,
    required this.onDone,
    required this.onAgain,
    required this.onDownloadSkipped,
  });

  final ImportDone state;
  final String companyName;
  final VoidCallback onDone;
  final VoidCallback onAgain;
  final VoidCallback onDownloadSkipped;

  @override
  Widget build(BuildContext context) {
    final skipped = state.skipped.length;
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: JitanColors.successSurface, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: JitanColors.success, size: 20),
          ),
          const SizedBox(height: 18),
          Text(
            context.tPlural(AdminTextKeys.employeeImportDoneTitle, state.result.added, args: {'company': companyName}),
            textAlign: TextAlign.center,
            style: JitanTextStyles.stateTitle.copyWith(fontSize: 22),
          ),
          if (skipped > 0) ...[
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text(
                  context.tPlural(AdminTextKeys.employeeImportDoneSkipped, skipped),
                  style: JitanTextStyles.tableCell.copyWith(fontSize: 15, color: JitanColors.inkMuted),
                ),
                Semantics(
                  link: true,
                  child: InkWell(
                    onTap: onDownloadSkipped,
                    child: Text(
                      context.t(AdminTextKeys.employeeImportDownloadSkipped),
                      style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 15, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          JitanPrimaryButton(label: context.t(AdminTextKeys.employeeImportDone), onPressed: onDone),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onAgain,
            style: TextButton.styleFrom(foregroundColor: JitanColors.inkMuted),
            child: Text(
              context.t(AdminTextKeys.employeeImportDoneAgain),
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

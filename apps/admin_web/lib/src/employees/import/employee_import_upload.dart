import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../l10n/admin_text_keys.dart';
import 'employee_import_controller.dart';
import 'employee_import_file.dart';
import 'employee_import_text.dart';
import 'platform/import_file_picker.dart';

/// The upload card of Import employees: "Ready" (`1419:2`), "Reading file"
/// (`1419:50`) and "File can't be used" (`1419:101`). A file can be dropped
/// on it or chosen with the button, once a company is chosen ([onChoose] and
/// [onDropped] `null` until then).
class EmployeeImportUpload extends StatefulWidget {
  const EmployeeImportUpload({super.key, required this.state, required this.onChoose, required this.onDropped});

  /// [ImportWaitingForFile], [ImportReading] or [ImportUnusable].
  final EmployeeImportState state;
  final VoidCallback? onChoose;
  final ValueChanged<ChosenImportFile>? onDropped;

  @override
  State<EmployeeImportUpload> createState() => _EmployeeImportUploadState();
}

class _EmployeeImportUploadState extends State<EmployeeImportUpload> {
  var _dragging = false;

  Future<void> _drop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    final file = details.files.firstOrNull;
    final onDropped = widget.onDropped;
    if (file == null || onDropped == null) return;
    onDropped(ChosenImportFile(name: file.name, bytes: await file.readAsBytes()));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final unusable = state is ImportUnusable;
    final content = switch (state) {
      ImportReading(:final name, :final sizeBytes) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImportFileChip(name: name, details: EmployeeImportText.size(context, sizeBytes)),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: JitanColors.vermilion),
              ),
              const SizedBox(width: 8),
              Text(context.t(AdminTextKeys.employeeImportReading), style: _hint),
            ],
          ),
        ],
      ),
      ImportUnusable() => _message(
        context,
        title: context.t(AdminTextKeys.employeeImportUnusableTitle),
        titleColor: JitanColors.errorStrong,
        line: EmployeeImportText.unusable(context, state),
        button: context.t(AdminTextKeys.employeeImportChooseAnother),
      ),
      _ => _message(
        context,
        title: context.t(AdminTextKeys.employeeImportDropTitle),
        line: widget.onChoose == null
            ? context.t(AdminTextKeys.employeeImportDropHintNoCompany, args: {'max': EmployeeImportRequest.maxRows})
            : context.t(AdminTextKeys.employeeImportDropHint, args: {'max': EmployeeImportRequest.maxRows}),
        button: context.t(AdminTextKeys.employeeImportChoose),
      ),
    };
    final borderColor = switch ((unusable, _dragging)) {
      (_, true) => JitanColors.vermilion,
      (true, _) => JitanColors.errorStrong,
      _ => _dashColor,
    };
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      padding: const EdgeInsets.all(20),
      child: DropTarget(
        enable: state is! ImportReading && widget.onDropped != null,
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: _drop,
        child: CustomPaint(
          foregroundPainter: _DashedBorder(color: borderColor),
          child: Container(
            constraints: const BoxConstraints(minHeight: 180),
            decoration: BoxDecoration(
              color: _dragging ? JitanColors.brandTint : JitanColors.tableHeader,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _message(
    BuildContext context, {
    required String title,
    Color titleColor = JitanColors.ink,
    required String line,
    required String button,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: JitanTextStyles.stateTitle.copyWith(color: titleColor),
      ),
      const SizedBox(height: 6),
      Text(line, textAlign: TextAlign.center, style: _hint),
      const SizedBox(height: 18),
      JitanOutlineButton(label: button, onPressed: widget.onChoose, height: JitanDimensions.controlHeight),
    ],
  );

  static final _hint = JitanTextStyles.stateMessage.copyWith(fontSize: 13);
  static const _dashColor = Color(0xFFD6D3CC);
}

/// The chosen file (Figma "File / Chosen"): a small type badge, the name and
/// [details] ("50 rows · 18 KB"), and an optional trailing action.
class ImportFileChip extends StatelessWidget {
  const ImportFileChip({super.key, required this.name, required this.details, this.trailing});

  final String name;
  final String details;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final extension = name.contains('.') ? name.split('.').last.toUpperCase() : '';
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: JitanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: JitanColors.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: JitanColors.successSurface, borderRadius: BorderRadius.circular(4)),
            child: Text(
              extension.length > 4 ? extension.substring(0, 4) : extension,
              style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 8, color: JitanColors.success),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13),
                ),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (trailing case final trailing?) ...[const SizedBox(width: 16), trailing],
        ],
      ),
    );
  }
}

/// "Columns in the file" (Figma `Import / Columns`): what each column holds,
/// and the template to download.
class EmployeeImportColumnsCard extends StatelessWidget {
  const EmployeeImportColumnsCard({super.key, required this.onDownloadTemplate});

  final VoidCallback onDownloadTemplate;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t(AdminTextKeys.employeeImportColumnsTitle), style: JitanTextStyles.stateTitle),
        const SizedBox(height: 4),
        Text(
          context.t(AdminTextKeys.employeeImportColumnsSubtitle),
          style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
        ),
      ],
    );
    final template = TextButton(
      onPressed: onDownloadTemplate,
      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
      child: Text(
        context.t(AdminTextKeys.employeeImportTemplate),
        style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13, color: JitanColors.vermilion),
      ),
    );
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, const SizedBox(height: 4), template],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heading),
                      template,
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            // Two per row on a phone, otherwise one line as in Figma.
            builder: (context, constraints) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final column in ImportColumn.values)
                  SizedBox(
                    width: constraints.maxWidth < JitanDimensions.phoneBreakpoint
                        ? (constraints.maxWidth - 16) / 2
                        : 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.t(EmployeeImportText.columnKey(column)), style: JitanTextStyles.tableCellStrong),
                        const SizedBox(height: 4),
                        Text(
                          context.t(switch (column) {
                            _ when column.required => AdminTextKeys.employeeImportColumnRequired,
                            ImportColumn.groups => AdminTextKeys.employeeImportColumnGroupsNote,
                            _ => AdminTextKeys.employeeImportColumnOptional,
                          }),
                          style: JitanTextStyles.tableCell.copyWith(
                            fontSize: 12,
                            color: column.required ? JitanColors.ink : JitanColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded dashed outline (the drop area).
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)));
    for (final metric in outline.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 10) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

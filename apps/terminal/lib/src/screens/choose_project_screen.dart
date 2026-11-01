import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/terminal_text_keys.dart';
import '../widgets/terminal_styles.dart';
import 'message_screen.dart';
import 'project_text.dart';

/// Figma `1494:65`: one list of their projects and Transport. A tap switches.
class ChooseProjectScreen extends StatelessWidget {
  const ChooseProjectScreen({
    super.key,
    required this.result,
    required this.busy,
    required this.failed,
    required this.onChoose,
    required this.onKeep,
  });

  final TerminalScanResult result;
  final bool busy;
  final bool failed;
  final void Function(ActivityKind kind, int? projectId) onChoose;
  final VoidCallback onKeep;

  Widget _row({
    required String title,
    required String detail,
    required bool selected,
    required VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(title, overflow: TextOverflow.ellipsis, style: TerminalStyles.rowTitle),
                Text(detail, overflow: TextOverflow.ellipsis, style: TerminalStyles.rowDetail),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check, color: JitanColors.success, size: 24),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final current = result.current;
    final rows = [
      for (final project in result.projects)
        _row(
          title: project.name,
          detail: ProjectText.detail(context, project),
          selected: project.id == current?.project?.id && current?.kind != ActivityKind.transport,
          onTap: busy ? null : () => onChoose(ProjectText.kindOf(project), project.id),
        ),
      _row(
        title: context.t(TerminalTextKeys.transport),
        detail: context.t(TerminalTextKeys.transportHint),
        selected: current?.kind == ActivityKind.transport,
        onTap: busy ? null : () => onChoose(ActivityKind.transport, null),
      ),
    ];
    final keep = current?.project;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 24, 40, 32),
        child: SizedBox(
          width: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t(TerminalTextKeys.chooseTitle), style: TerminalStyles.title.copyWith(fontSize: 32)),
              const SizedBox(height: 6),
              if (result.firstName case final name?) Text(name, style: TerminalStyles.hint),
              const SizedBox(height: 24),
              Material(
                color: JitanColors.surface,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, row) in rows.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: JitanColors.inputBorder),
                      row,
                    ],
                  ],
                ),
              ),
              if (failed) ...[
                const SizedBox(height: 12),
                Text(context.t(TerminalTextKeys.chooseFailed), style: TerminalStyles.hint.copyWith(color: JitanColors.warning)),
              ],
              const SizedBox(height: 20),
              TerminalButton(
                large: true,
                label: keep == null
                    ? context.t(TerminalTextKeys.keepCurrent)
                    : context.t(TerminalTextKeys.keepProject, args: {'project': keep.name}),
                onPressed: busy ? null : onKeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

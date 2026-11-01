import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/terminal_text_keys.dart';
import '../widgets/terminal_styles.dart';
import 'message_screen.dart';
import 'project_text.dart';

/// Figma `1489:28` Checked in, `1494:2` Checked out and `1494:18` Already
/// checked in. It goes back to the camera by itself, so there is no Done.
class RegisteredScreen extends StatelessWidget {
  const RegisteredScreen({super.key, required this.result, required this.hour, required this.onChange});

  final TerminalScanResult result;

  /// The tablet's hour, for the greeting.
  final int hour;
  final VoidCallback onChange;

  String _greeting(BuildContext context) {
    final part = hour < 12
        ? TerminalTextKeys.morning
        : hour < 18
        ? TerminalTextKeys.afternoon
        : TerminalTextKeys.evening;
    final name = result.firstName;
    return name == null ? context.t(TerminalTextKeys.hello) : context.t(part, args: {'name': name});
  }

  Widget _project(BuildContext context, MyProject project) => Container(
    width: 520,
    padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
    decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(16)),
    child: Row(
      spacing: 20,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Text(project.name, overflow: TextOverflow.ellipsis, style: TerminalStyles.rowTitle.copyWith(fontSize: 16)),
              Text(ProjectText.detail(context, project), overflow: TextOverflow.ellipsis, style: TerminalStyles.rowDetail),
            ],
          ),
        ),
        TerminalButton(label: context.t(TerminalTextKeys.change), onPressed: onChange),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final time = {'time': result.timeLocal};
    final name = result.firstName;
    final project = result.current?.project;
    final back = [
      const SizedBox(height: 28),
      Text(context.t(TerminalTextKeys.backSoon), style: TerminalStyles.quiet),
    ];
    return switch (result.outcome) {
      TerminalScanOutcome.checkedIn => MessageScreen(
        tone: MessageTone.good,
        title: _greeting(context),
        text: context.t(TerminalTextKeys.checkedInAt, args: time),
        below: [
          // Nothing to change without a project to change from or to.
          if (project != null || result.projects.isNotEmpty) ...[
            const SizedBox(height: 36),
            if (project != null)
              _project(context, project)
            else
              TerminalButton(label: context.t(TerminalTextKeys.change), onPressed: onChange),
          ],
          ...back,
        ],
      ),
      TerminalScanOutcome.checkedOut => MessageScreen(
        tone: MessageTone.good,
        title: name == null ? context.t(TerminalTextKeys.goodbye) : context.t(TerminalTextKeys.goodbyeName, args: {'name': name}),
        text: context.t(TerminalTextKeys.checkedOutAt, args: time),
        below: back,
      ),
      TerminalScanOutcome.alreadyCheckedIn => MessageScreen(
        tone: MessageTone.neutral,
        title: context.t(TerminalTextKeys.alreadyIn),
        text: context.t(TerminalTextKeys.alreadyInSince, args: time),
        below: back,
      ),
      TerminalScanOutcome.alreadyCheckedOut => MessageScreen(
        tone: MessageTone.neutral,
        title: context.t(TerminalTextKeys.alreadyOut),
        text: context.t(TerminalTextKeys.alreadyOutAt, args: time),
        below: back,
      ),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../flow/terminal_view.dart';
import '../l10n/terminal_text_keys.dart';
import '../widgets/camera_panel.dart';
import '../widgets/terminal_styles.dart';

/// Figma `1489:94`, and `1494:101` for a code that no longer works: one screen
/// instead of the old steps and separate scan screen.
class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key, required this.camera, required this.onRead, required this.problem});

  final QrCamera camera;
  final ValueChanged<String> onRead;
  final ConnectProblem problem;

  @override
  Widget build(BuildContext context) {
    final (title, text) = switch (problem) {
      ConnectProblem.none => (TerminalTextKeys.connectTitle, TerminalTextKeys.connectText),
      ConnectProblem.expired => (TerminalTextKeys.connectExpired, TerminalTextKeys.connectExpiredText),
      ConnectProblem.unreadable => (TerminalTextKeys.connectUnreadable, TerminalTextKeys.connectUnreadableText),
      ConnectProblem.noConnection => (TerminalTextKeys.noConnectionTitle, TerminalTextKeys.noConnectionText),
    };
    final warn = problem != ConnectProblem.none;
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 24, 56, 40),
      child: Row(
        spacing: 56,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Text(
                  context.t(title),
                  style: warn
                      ? TerminalStyles.title.copyWith(fontSize: 30, color: JitanColors.warning)
                      : TerminalStyles.title.copyWith(fontSize: 40),
                ),
                Text(context.t(text), style: TerminalStyles.body),
              ],
            ),
          ),
          Expanded(
            child: Center(child: CameraPanel(camera: camera, onRead: onRead)),
          ),
        ],
      ),
    );
  }
}

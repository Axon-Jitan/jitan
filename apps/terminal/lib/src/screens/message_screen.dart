import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../widgets/terminal_styles.dart';

enum MessageTone { good, neutral, attention }

/// One thing to say, in the middle of the tablet: checked in or out, the same
/// scan again, ask HR, no connection, tablet ready.
class MessageScreen extends StatelessWidget {
  const MessageScreen({
    super.key,
    required this.tone,
    required this.title,
    required this.text,
    this.below = const [],
  });

  final MessageTone tone;
  final String title;
  final String text;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final (color, tint) = switch (tone) {
      MessageTone.good => (JitanColors.success, JitanColors.successSurface),
      MessageTone.neutral => (JitanColors.ink, JitanColors.inputFill),
      MessageTone.attention => (JitanColors.warning, JitanColors.warningSurface),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(tone == MessageTone.attention ? Icons.priority_high : Icons.check, size: 44, color: color),
            ),
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center, style: TerminalStyles.title),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: TerminalStyles.body),
            ...below,
          ],
        ),
      ),
    );
  }
}

/// The soft button of the tablet.
class TerminalButton extends StatelessWidget {
  const TerminalButton({super.key, required this.label, required this.onPressed, this.large = false});

  final String label;
  final VoidCallback? onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: JitanColors.inputFill,
      foregroundColor: JitanColors.ink,
      padding: large ? const EdgeInsets.symmetric(horizontal: 26, vertical: 16) : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: TerminalStyles.button.copyWith(fontSize: large ? 16 : 14),
    ),
    child: Text(label),
  );
}

import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// A loading, empty or error state as Figma draws it on the Employee groups
/// screens: one line of text. With [onRetry] it is the red "Try again →".
class GroupStateText extends StatelessWidget {
  const GroupStateText(this.text, {super.key, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final line = Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        style: JitanTextStyles.stateMessage.copyWith(color: onRetry == null ? null : JitanColors.vermilion),
      ),
    );
    final retry = onRetry;
    return Align(
      alignment: Alignment.topLeft,
      child: retry == null
          ? line
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(onTap: retry, child: line),
            ),
    );
  }
}

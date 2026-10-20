import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';

/// The "⋯" of a table row (table design specification §7): a dark charcoal
/// icon, no background or border, a comfortable invisible click area, and
/// keyboard accessible. It opens the row's management popup; it never acts
/// on its own.
class JitanRowActionsButton extends StatelessWidget {
  const JitanRowActionsButton({super.key, required this.tooltip, required this.onPressed});

  /// Also the accessible name, e.g. "Schedule actions".
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 36),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          hoverColor: JitanColors.inputFill,
        ),
        icon: const Icon(Icons.more_horiz, size: 22, color: JitanColors.ink),
      );
}

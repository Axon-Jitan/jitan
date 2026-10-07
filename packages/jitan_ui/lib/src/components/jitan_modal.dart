import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// The white rounded modal from the Figma web flows ("Add employee", …):
/// title, optional one-line subtitle, scrollable body, optional actions
/// bottom-right. Without actions it is closed by Escape or a tap outside.
///
/// Narrower than [JitanDimensions.modalWidth] on small screens.
class JitanModal extends StatelessWidget {
  const JitanModal({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.width,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;

  /// Fixed width (still narrower on small screens); otherwise sized to the
  /// content, up to [JitanDimensions.modalWidth].
  final double? width;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: JitanColors.surface,
        surfaceTintColor: JitanColors.surface,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JitanDimensions.modalRadius)),
        child: ConstrainedBox(
          constraints: width == null
              ? const BoxConstraints(maxWidth: JitanDimensions.modalWidth)
              : BoxConstraints.tightFor(width: width),
          child: Padding(
            padding: const EdgeInsets.all(JitanDimensions.modalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: JitanTextStyles.modalTitle)),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(subtitle!, style: JitanTextStyles.modalSubtitle),
                ],
                const SizedBox(height: 32),
                Flexible(child: SingleChildScrollView(child: body)),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

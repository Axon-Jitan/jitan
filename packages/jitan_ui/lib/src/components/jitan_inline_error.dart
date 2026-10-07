import 'package:flutter/widgets.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// A form-level error (not tied to one field), e.g. "Can't reach Jitan".
class JitanInlineError extends StatelessWidget {
  const JitanInlineError({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: JitanColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: JitanTextStyles.stateTitle.copyWith(fontSize: 11, color: JitanColors.error)),
                const SizedBox(height: 2),
                Text(message, style: JitanTextStyles.stateMessage),
              ],
            ),
          ),
        ),
      );
}

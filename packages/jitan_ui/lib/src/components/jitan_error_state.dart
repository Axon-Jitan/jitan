import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// Shown when loading failed. Offers [retryLabel] when [onRetry] is given.
class JitanErrorState extends StatelessWidget {
  const JitanErrorState({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
  }) : assert((retryLabel == null) == (onRetry == null), 'Give both retryLabel and onRetry, or neither.');

  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: JitanTextStyles.stateTitle, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(message, style: JitanTextStyles.stateMessage, textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: JitanDimensions.controlHeight,
                    child: FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        backgroundColor: JitanColors.vermilion,
                        foregroundColor: JitanColors.surface,
                        textStyle: JitanTextStyles.buttonLabel,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
                        ),
                      ),
                      child: Text(retryLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

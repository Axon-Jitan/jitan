import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';
import 'jitan_primary_button.dart';

/// The centred confirmation after a saved change (Figma `HR / Time records —
/// Correction saved` 272:547): a green check, title, subtitle, message and
/// one full-width button. Shown only after the server confirmed (rule §21).
class JitanSuccessModal extends StatelessWidget {
  const JitanSuccessModal({
    super.key,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onDone,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String message;
  final String buttonLabel;

  /// The button and the "×".
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: JitanColors.surface,
    surfaceTintColor: JitanColors.surface,
    insetPadding: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JitanDimensions.modalRadius)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: JitanColors.successSurface, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 28, color: JitanColors.success),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(title, textAlign: TextAlign.center, style: JitanTextStyles.modalTitle.copyWith(fontSize: 22)),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 10),
                  Text(subtitle!, textAlign: TextAlign.center, style: JitanTextStyles.modalSubtitle),
                ],
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: JitanTextStyles.stateMessage.copyWith(fontSize: 13, color: JitanColors.ink),
                ),
                const SizedBox(height: 28),
                JitanPrimaryButton(label: buttonLabel, onPressed: onDone),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onDone,
              icon: const Icon(Icons.close, size: 20, color: JitanColors.inkMuted),
            ),
          ),
        ],
      ),
    ),
  );
}

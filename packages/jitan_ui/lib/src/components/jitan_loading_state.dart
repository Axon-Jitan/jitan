import 'package:flutter/material.dart';

import '../theme/jitan_text_styles.dart';

/// Centered spinner with a short label, shown while data loads.
class JitanLoadingState extends StatelessWidget {
  const JitanLoadingState({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          liveRegion: true,
          label: label,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(height: 12),
              Text(label, style: JitanTextStyles.stateMessage),
            ],
          ),
        ),
      );
}

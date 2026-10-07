import 'package:flutter/widgets.dart';

import '../theme/jitan_text_styles.dart';

/// Shown when a list loaded successfully but has nothing to display.
class JitanEmptyState extends StatelessWidget {
  const JitanEmptyState({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: JitanTextStyles.stateTitle, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(message, style: JitanTextStyles.stateMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

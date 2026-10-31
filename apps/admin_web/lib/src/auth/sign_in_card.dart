import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// The page around sign-in: the logo and one small card, nothing else.
class SignInCard extends StatelessWidget {
  const SignInCard({super.key, required this.children, this.footnote});

  final List<Widget> children;

  /// A quiet line under the card.
  final String? footnote;

  static const _width = 420.0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: JitanColors.warmWhite,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned(left: 40, top: 28, child: Text('jitan.', style: JitanTextStyles.logo)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 72, 16, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _width),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: JitanColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [BoxShadow(color: Color(0x0D182021), blurRadius: 40, offset: Offset(0, 12))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                    ),
                    if (footnote case final text?) ...[
                      const SizedBox(height: 20),
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

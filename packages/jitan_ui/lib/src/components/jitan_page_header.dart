import 'package:flutter/widgets.dart';

import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// Page title and one-line description (e.g. "Companies" /
/// "View and manage companies in Jitan."), with an optional [action] (e.g.
/// "Add schedule") on the right, or under the text on a phone-sized window.
class JitanPageHeader extends StatelessWidget {
  const JitanPageHeader({super.key, required this.title, required this.subtitle, this.action});

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: JitanTextStyles.pageTitle)),
        const SizedBox(height: 8),
        Text(subtitle, style: JitanTextStyles.pageSubtitle),
      ],
    );
    final action = this.action;
    if (action == null) return text;
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 16), action],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: text), const SizedBox(width: 16), action],
            ),
    );
  }
}

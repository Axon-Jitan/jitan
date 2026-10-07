import 'package:flutter/widgets.dart';

import '../theme/jitan_text_styles.dart';

/// Page title and one-line description (e.g. "Companies" /
/// "View and manage companies in Jitan.").
class JitanPageHeader extends StatelessWidget {
  const JitanPageHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: JitanTextStyles.pageTitle)),
          const SizedBox(height: 8),
          Text(subtitle, style: JitanTextStyles.pageSubtitle),
        ],
      );
}

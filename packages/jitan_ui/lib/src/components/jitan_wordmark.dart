import 'package:flutter/widgets.dart';

import '../theme/jitan_mobile_text_styles.dart';

/// The "jitan." wordmark.
class JitanWordmark extends StatelessWidget {
  const JitanWordmark({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: Text('jitan.', style: style ?? JitanMobileTextStyles.logo));
}

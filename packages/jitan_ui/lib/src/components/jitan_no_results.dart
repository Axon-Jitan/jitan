import 'package:flutter/widgets.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// A search or filter that shows nothing (Locations `1543:114`, Terminals
/// `1545:830`): calmly on the page itself, no card.
class JitanNoResults extends StatelessWidget {
  const JitanNoResults({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 96),
    child: Column(
      spacing: 6,
      children: [
        Text(title, textAlign: TextAlign.center, style: JitanTextStyles.stateTitle.copyWith(fontSize: 17)),
        Text(message, textAlign: TextAlign.center, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
      ],
    ),
  );
}

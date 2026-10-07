import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// One label/value pair of a [JitanDetailGrid].
class JitanDetailItem {
  const JitanDetailItem({required this.label, required this.value, this.tooltip});

  final String label;
  final String value;

  /// Explains a placeholder value (e.g. why it shows "—").
  final String? tooltip;
}

/// The light grey card of label/value pairs in Figma detail modals
/// ("Employee type: White collar", …), three per row, two when narrow.
class JitanDetailGrid extends StatelessWidget {
  const JitanDetailGrid({super.key, required this.items});

  final List<JitanDetailItem> items;

  static const _wideColumns = 3;
  static const _narrowColumns = 2;
  static const _narrowBreakpoint = 480.0;
  static const _padding = 18.0;
  static const _runSpacing = 26.0;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < _narrowBreakpoint ? _narrowColumns : _wideColumns;
              final width = constraints.maxWidth / columns;
              return Wrap(
                runSpacing: _runSpacing,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label, style: JitanTextStyles.fieldLabel),
                          const SizedBox(height: 8),
                          _value(item),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );

  static Widget _value(JitanDetailItem item) {
    final text = Text(item.value, style: JitanTextStyles.tableCellStrong, overflow: TextOverflow.ellipsis);
    return item.tooltip == null ? text : Tooltip(message: item.tooltip, child: text);
  }
}

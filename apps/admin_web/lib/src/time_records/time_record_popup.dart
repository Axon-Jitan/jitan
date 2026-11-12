import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// Every Time records pop-up (Figma `1566:*`): 560 × 560, so going from a
/// day to its correction, or switching "Add the finish" and "Not a work
/// day", never makes it jump. The title and subtitle on top, the [body] in
/// the middle (scrolling inside when there is more, as in the wizards), the
/// [bottom] note and the buttons at the foot. On a short screen it is as
/// high as fits.
class TimeRecordPopup extends StatelessWidget {
  const TimeRecordPopup({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
    this.bottom,
    this.leadingActions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> body;
  final Widget? bottom;
  final List<Widget> actions;

  /// At the left of the buttons (Reject).
  final List<Widget> leadingActions;

  static const size = 560.0;
  static const _inset = 16.0;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final height = math.min(size, screen.height - padding.vertical - _inset * 2);
    return Dialog(
      backgroundColor: JitanColors.surface,
      surfaceTintColor: JitanColors.surface,
      insetPadding: const EdgeInsets.all(_inset),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JitanDimensions.modalRadius)),
      child: SizedBox(
        width: size,
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanTextStyles.modalTitle.copyWith(fontSize: 24)),
              ),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: JitanTextStyles.modalSubtitle.copyWith(fontSize: 13)),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
                ),
              ),
              if (bottom case final bottom?) ...[const SizedBox(height: 16), bottom],
              const SizedBox(height: 20),
              OverflowBar(
                alignment: leadingActions.isEmpty ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.end,
                overflowDirection: VerticalDirection.up,
                spacing: 12,
                overflowSpacing: 10,
                children: [
                  if (leadingActions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: leadingActions),
                  Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: actions),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

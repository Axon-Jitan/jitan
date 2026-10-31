import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// Small capitals above a card or field ("YOUR SCHEDULE TODAY", "START
/// TIME").
class TodayEyebrow extends StatelessWidget {
  const TodayEyebrow(this.text, {super.key, this.color = JitanColors.inkMuted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: JitanMobileTextStyles.fieldLabel.copyWith(color: color, letterSpacing: 0.3));
}

/// The white rounded card of the Today screens.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: JitanColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: JitanColors.inputBorder),
    ),
    child: child,
  );
}

/// "● WORKING NOW" / "● COMPLETE": a dot and small capitals, on a grey pill
/// when [filled].
class TodayChip extends StatelessWidget {
  const TodayChip({super.key, required this.label, this.filled = false, this.color = JitanColors.ink, this.tinted = false});

  final String label;
  final bool filled;
  final Color color;

  /// The pill takes a tint of [color] (AWAY, NEEDS ATTENTION).
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: JitanMobileTextStyles.fieldLabel.copyWith(color: color, letterSpacing: 0.3)),
      ],
    );
    return filled
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tinted ? color.withValues(alpha: 0.12) : JitanColors.inputFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: content,
          )
        : content;
  }
}

/// The red link above the main button ("Forgot to start? Enter when you
/// arrived →").
class TodayLink extends StatelessWidget {
  const TodayLink({super.key, required this.label, required this.onPressed, this.fontSize = 13});

  final String label;
  final VoidCallback? onPressed;
  final double fontSize;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: JitanColors.vermilion,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      minimumSize: const Size(0, 36),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: JitanMobileTextStyles.link.copyWith(color: JitanColors.vermilion, fontSize: fontSize),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.arrow_forward, size: fontSize + 1, color: JitanColors.vermilion),
      ],
    ),
  );
}

/// A red note: a save that failed (Figma 1436:84).
class TodayErrorBox extends StatelessWidget {
  const TodayErrorBox({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: JitanColors.errorSurface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: JitanMobileTextStyles.noteTitleLarge.copyWith(color: JitanColors.errorStrong)),
          const SizedBox(height: 6),
          Text(message, style: JitanMobileTextStyles.cardText.copyWith(color: JitanColors.errorStrong)),
        ],
      ),
    ),
  );
}

/// One tab of [EmployeeNavBar].
class EmployeeNavItem {
  const EmployeeNavItem({required this.icon, required this.label, required this.onTap, this.selected = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
}

/// The white bar at the bottom of the Employee App (Figma "Nav / …").
class EmployeeNavBar extends StatelessWidget {
  const EmployeeNavBar({super.key, required this.items});

  final List<EmployeeNavItem> items;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
    child: Row(
      children: [
        for (final item in items)
          Expanded(
            child: Semantics(
              selected: item.selected,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: item.onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 22, color: item.selected ? JitanColors.vermilion : JitanColors.inkMuted),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: JitanMobileTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: item.selected ? FontWeight.w600 : FontWeight.w400,
                        color: item.selected ? JitanColors.vermilion : JitanColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

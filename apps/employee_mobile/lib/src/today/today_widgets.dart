import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

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

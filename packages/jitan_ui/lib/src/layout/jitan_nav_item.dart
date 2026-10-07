import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// One destination in the web sidebar.
class JitanNavDestination {
  const JitanNavDestination({required this.label, required this.path});

  final String label;

  /// Route path this item navigates to.
  final String path;
}

/// Sidebar navigation item; highlighted when [selected].
class JitanNavItem extends StatelessWidget {
  const JitanNavItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? JitanColors.sidebarItemActive : JitanColors.sidebarBackground,
          borderRadius: BorderRadius.circular(JitanDimensions.navItemRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(JitanDimensions.navItemRadius),
            hoverColor: JitanColors.sidebarItemActive,
            child: SizedBox(
              height: JitanDimensions.navItemHeight,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: JitanDimensions.navItemTextInset),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: selected ? JitanTextStyles.navItemActive : JitanTextStyles.navItem,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

import 'package:flutter/widgets.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';
import 'jitan_nav_item.dart';

/// Dark web sidebar: "jitan." logo, optional role caption, navigation.
class JitanWebSidebar extends StatelessWidget {
  const JitanWebSidebar({
    super.key,
    required this.destinations,
    required this.selectedPath,
    required this.onNavigate,
    this.roleCaption,
  });

  final List<JitanNavDestination> destinations;
  final String selectedPath;
  final ValueChanged<String> onNavigate;

  /// e.g. "ADMIN" / "HR". Omitted when unknown; never guessed.
  final String? roleCaption;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: JitanColors.sidebarBackground,
        child: SizedBox(
          width: JitanDimensions.sidebarWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: JitanDimensions.sidebarLogoInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: JitanDimensions.sidebarLogoInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('jitan.', style: JitanTextStyles.logo),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 12,
                        child: roleCaption == null
                            ? null
                            : Text(roleCaption!, style: JitanTextStyles.sidebarCaption),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: JitanDimensions.sidebarHorizontalPadding),
                  child: Column(
                    children: [
                      for (final destination in destinations) ...[
                        JitanNavItem(
                          label: destination.label,
                          selected: selectedPath.startsWith(destination.path),
                          onTap: () => onNavigate(destination.path),
                        ),
                        const SizedBox(height: JitanDimensions.navItemSpacing),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

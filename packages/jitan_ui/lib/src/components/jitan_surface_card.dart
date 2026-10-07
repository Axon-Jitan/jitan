import 'package:flutter/widgets.dart';

import '../theme/jitan_colors.dart';

/// White rounded surface used for toolbars and tables on web pages.
class JitanSurfaceCard extends StatelessWidget {
  const JitanSurfaceCard({
    super.key,
    required this.radius,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: JitanColors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      );
}

import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';

/// The layout of a web list page (Employees, Companies, Schedules, Groups),
/// as list tools like Linear, Notion or Stripe do it: the [top] (title,
/// actions, filters) stays in place and only the [list] scrolls, a soft
/// line marking the edge once rows pass under it. On a phone or a short
/// window the fixed part would leave the list too little room, so there the
/// whole page scrolls.
///
/// [list] are slivers, e.g. a [JitanSliverTable] or a state card.
class JitanListPage extends StatefulWidget {
  const JitanListPage({super.key, required this.top, required this.list});

  final Widget top;
  final List<Widget> list;

  /// Below this window height the top scrolls with the list.
  static const fixedTopMinHeight = 640.0;

  @override
  State<JitanListPage> createState() => _JitanListPageState();
}

class _JitanListPageState extends State<JitanListPage> {
  /// Keeps the top (open menus, focus, typed text) when the page switches
  /// between a fixed top and one scroll.
  final _topKey = GlobalKey();
  var _scrolled = false;

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    final padding = JitanDimensions.pagePadding(window.width);
    final top = KeyedSubtree(key: _topKey, child: widget.top);
    // Decided from the window, which stays the same while a field gains or
    // loses focus (the page's own height may briefly change then).
    final fixedTop = window.width >= JitanDimensions.phoneBreakpoint && window.height >= JitanListPage.fixedTopMinHeight;
    if (!fixedTop) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: SliverMainAxisGroup(slivers: [SliverToBoxAdapter(child: top), ...widget.list]),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: padding.copyWith(bottom: 0), child: top),
        AnimatedOpacity(
          opacity: _scrolled ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Container(height: 1, color: JitanColors.inputBorder),
        ),
        Expanded(
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              final scrolled = notification.metrics.pixels > 0;
              if (notification.depth == 0 && scrolled != _scrolled) setState(() => _scrolled = scrolled);
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: padding.copyWith(top: 0),
                  sliver: SliverMainAxisGroup(slivers: widget.list),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

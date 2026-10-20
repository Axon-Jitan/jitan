import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';

/// Opens a modal (usually a [JitanModal]) over a blurred, lightly darkened
/// page, fading and scaling in. Use it instead of `showDialog` so every
/// dialog in the web apps opens the same way.
///
/// Dismissible by a tap outside or Escape, like `showDialog`.
Future<T?> showJitanModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.transparent,
  transitionDuration: _duration,
  pageBuilder: (context, _, _) => SafeArea(child: Builder(builder: builder)),
  transitionBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return Stack(
      children: [
        // The blurred backdrop; taps on it reach the barrier below.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, _) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: _blur * curved.value, sigmaY: _blur * curved.value),
                child: ColoredBox(color: JitanColors.ink.withValues(alpha: _dim * curved.value)),
              ),
            ),
          ),
        ),
        FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(curved), child: child),
        ),
      ],
    );
  },
);

const _duration = Duration(milliseconds: 220);
const _blur = 14.0;
const _dim = 0.28;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/terminal_text_keys.dart';
import '../widgets/camera_panel.dart';
import '../widgets/terminal_styles.dart';

/// Figma `1489:2`, and `1489:51` when a code wasn't read: the camera is the
/// home screen, so nobody has to tap anything. No camera while HR has
/// switched scanning off here.
class ScanHomeScreen extends StatefulWidget {
  const ScanHomeScreen({
    super.key,
    required this.camera,
    required this.onRead,
    required this.unreadable,
    required this.canScan,
    required this.clock,
  });

  final QrCamera camera;
  final ValueChanged<String> onRead;
  final bool unreadable;
  final bool canScan;
  final DateTime Function() clock;

  @override
  State<ScanHomeScreen> createState() => _ScanHomeScreenState();
}

class _ScanHomeScreenState extends State<ScanHomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _date(BuildContext context, DateTime now) => context.t(
    TerminalTextKeys.clockDate,
    args: {
      'weekday': context.t(CommonTextKeys.weekdayLong[now.weekday - 1]),
      'day': now.day,
      'month': context.t(CommonTextKeys.monthLong[now.month - 1]),
    },
  );

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final hour = now.hour.toString().padLeft(2, '0'), minute = now.minute.toString().padLeft(2, '0');
    final (title, hint, warn) = !widget.canScan
        ? (TerminalTextKeys.scanOffTitle, TerminalTextKeys.scanOffHint, true)
        : widget.unreadable
        ? (TerminalTextKeys.scanFailedTitle, TerminalTextKeys.scanFailedHint, true)
        : (TerminalTextKeys.scanTitle, TerminalTextKeys.scanHint, false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 24, 56, 40),
      child: Row(
        spacing: 56,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(child: Text('$hour:$minute', style: TerminalStyles.clock)),
                Text(_date(context, now), style: TerminalStyles.date),
                const SizedBox(height: 40),
                Text(
                  context.t(title),
                  style: TerminalStyles.prompt.copyWith(color: warn ? JitanColors.warning : JitanColors.ink),
                ),
                const SizedBox(height: 8),
                Text(context.t(hint), style: TerminalStyles.hint),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: widget.canScan ? CameraPanel(camera: widget.camera, onRead: widget.onRead) : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

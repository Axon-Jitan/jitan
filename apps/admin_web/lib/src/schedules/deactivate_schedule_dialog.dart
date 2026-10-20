import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'schedule_rows.dart';
import 'schedules_controller.dart';

/// Asks HR to confirm switching [row]'s schedule off and does it. `true`
/// once the server confirmed.
Future<bool> showDeactivateScheduleDialog(
  BuildContext context, {
  required SchedulesController controller,
  required ScheduleRow row,
}) async =>
    await showJitanModal<bool>(
      context,
      builder: (_) => DeactivateScheduleDialog(controller: controller, row: row),
    ) ??
    false;

/// Figma `HR / Schedules — Deactivate confirmation` (1320:554). The rows
/// are switched off and kept (Active = 0, MFD = 1), and every change is in
/// `tblEventLog`; registrations already made keep their times.
class DeactivateScheduleDialog extends StatefulWidget {
  const DeactivateScheduleDialog({super.key, required this.controller, required this.row});

  final SchedulesController controller;
  final ScheduleRow row;

  @override
  State<DeactivateScheduleDialog> createState() => _DeactivateScheduleDialogState();
}

class _DeactivateScheduleDialogState extends State<DeactivateScheduleDialog> {
  bool _busy = false;
  ApiClientException? _failure;

  Future<void> _deactivate() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await widget.controller.deactivate(widget.row);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _failure = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final group = widget.row.group.name;
    return JitanModal(
      width: 610,
      title: context.t(AdminTextKeys.scheduleDeactivateTitle),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(
              widget.row.kind == ScheduleKind.workHours
                  ? AdminTextKeys.scheduleDeactivateWorkHours
                  : AdminTextKeys.scheduleDeactivateBreaks,
              args: {'group': group},
            ),
            style: JitanTextStyles.stateTitle.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(context.t(AdminTextKeys.scheduleDeactivateKeep), style: JitanTextStyles.stateMessage),
          if (failure != null) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final keys = failureTextKeysFor(failure);
                return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
              },
            ),
          ],
        ],
      ),
      actions: [
        JitanSecondaryButton(
          label: context.t(CommonTextKeys.cancel),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.scheduleDeactivateConfirm),
          busy: _busy,
          onPressed: _busy ? null : _deactivate,
        ),
      ],
    );
  }
}

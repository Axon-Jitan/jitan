import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/web_text.dart';
import '../l10n/employee_web_text_keys.dart';

/// `true` when HR got it, after the confirmation was shown.
Future<bool> showAddTimeDialog(
  BuildContext context, {
  required TimeRegistrationsApi api,
  required DateTime date,
  required RegistrationBoundary boundary,
  DateTime Function()? clock,
}) async {
  final sent =
      await showJitanModal<bool>(
        context,
        barrierDismissible: false,
        builder: (_) => _AddTimeDialog(api: api, date: date, boundary: boundary, clock: clock ?? DateTime.now),
      ) ??
      false;
  if (!sent || !context.mounted) return sent;
  await showJitanModal<void>(
    context,
    builder: (dialog) => JitanSuccessModal(
      title: dialog.t(EmployeeWebTextKeys.sentTitle),
      message: dialog.t(boundary == RegistrationBoundary.start ? EmployeeWebTextKeys.sentStart : EmployeeWebTextKeys.sentFinish),
      buttonLabel: dialog.t(EmployeeWebTextKeys.done),
      onDone: () => Navigator.of(dialog).pop(),
    ),
  );
  return true;
}

/// Add a missing time (Figma `1499:1034`). With a reason, it waits for HR
/// (D30, D31): nothing counts until HR has checked it.
class _AddTimeDialog extends StatefulWidget {
  const _AddTimeDialog({required this.api, required this.date, required this.boundary, required this.clock});

  final TimeRegistrationsApi api;
  final DateTime date;
  final RegistrationBoundary boundary;
  final DateTime Function() clock;

  @override
  State<_AddTimeDialog> createState() => _AddTimeDialogState();
}

class _AddTimeDialogState extends State<_AddTimeDialog> {
  static final _time = RegExp(r'^([01]?\d|2[0-3])[:.]([0-5]\d)$');

  final _at = TextEditingController();
  final _reason = TextEditingController();
  String? _timeError;
  String? _reasonError;
  bool _failed = false;
  bool _busy = false;

  bool get _isStart => widget.boundary == RegistrationBoundary.start;

  @override
  void dispose() {
    _at.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final match = _time.firstMatch(_at.text.trim());
    final date = widget.date;
    final at = match == null ? null : DateTime(date.year, date.month, date.day, int.parse(match.group(1)!), int.parse(match.group(2)!));
    setState(() {
      _failed = false;
      _timeError = at == null
          ? EmployeeWebTextKeys.addBadTime
          : at.isAfter(widget.clock())
          ? EmployeeWebTextKeys.addFuture
          : null;
      _reasonError = _reason.text.trim().isEmpty ? EmployeeWebTextKeys.addNoReason : null;
    });
    if (_timeError != null || _reasonError != null) return;
    setState(() => _busy = true);
    try {
      await widget.api.register(
        RegisterTimeRequest(
          boundary: widget.boundary,
          method: TimeRegistrationMethod.manual,
          entry: RegistrationEntry.corrected,
          at: at!.toUtc(),
          reason: _reason.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiClientException {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  String? _error(String? key) => key == null ? null : context.t(key);

  @override
  Widget build(BuildContext context) => JitanModal(
    width: 440,
    title: context.t(_isStart ? EmployeeWebTextKeys.addStart : EmployeeWebTextKeys.addFinish),
    subtitle: WebText.longDay(context, widget.date),
    onClose: () => Navigator.of(context).pop(false),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        JitanTextField(
          label: context.t(_isStart ? EmployeeWebTextKeys.addStartTime : EmployeeWebTextKeys.addFinishTime),
          controller: _at,
          hintText: '16:30',
          errorText: _error(_timeError),
        ),
        JitanTextField(
          label: context.t(EmployeeWebTextKeys.addWhy),
          controller: _reason,
          maxLength: RegisterTimeRequest.maxReasonLength,
          errorText: _error(_reasonError),
        ),
        Text(context.t(EmployeeWebTextKeys.addNote), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
        if (_failed) Text(context.t(EmployeeWebTextKeys.failed), style: JitanTextStyles.fieldError),
      ],
    ),
    actions: [
      JitanSecondaryButton(label: context.t(EmployeeWebTextKeys.cancel), onPressed: () => Navigator.of(context).pop(false)),
      JitanPrimaryButton(label: context.t(EmployeeWebTextKeys.addSend), busy: _busy, onPressed: _busy ? null : _send),
    ],
  );
}

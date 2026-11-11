import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Asks to deactivate [location]; completes with it, `null` when closed.
Future<Location?> showDeactivateLocationDialog(
  BuildContext context, {
  required LocationsApi api,
  required Location location,
}) => showJitanModal<Location>(context, builder: (_) => DeactivateLocationDialog(api: api, location: location));

/// Figma "Deactivate?" (`1543:3`): one plain question. Nothing is deleted:
/// Jitan stops recognising the place, its time stays, and it can be
/// reactivated.
class DeactivateLocationDialog extends StatefulWidget {
  const DeactivateLocationDialog({super.key, required this.api, required this.location});

  final LocationsApi api;
  final Location location;

  @override
  State<DeactivateLocationDialog> createState() => _DeactivateLocationDialogState();
}

class _DeactivateLocationDialogState extends State<DeactivateLocationDialog> {
  bool _busy = false;
  ApiClientException? _failure;

  Future<void> _deactivate() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final done = await widget.api.deactivate(widget.location.id);
      if (mounted) Navigator.of(context).pop(done);
    } on ApiClientException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => JitanModal(
    width: 440,
    title: context.t(AdminTextKeys.locationDeactivateTitle, args: {'location': widget.location.name}),
    subtitle: context.t(AdminTextKeys.locationDeactivateText),
    body: switch (_failure) {
      null => null,
      final failure => Builder(
        builder: (context) {
          final keys = failureTextKeysFor(failure);
          return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
        },
      ),
    },
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 10,
        children: [
          JitanSecondaryButton(
            label: context.t(CommonTextKeys.cancel),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          JitanPrimaryButton(
            label: context.t(AdminTextKeys.locationDeactivate),
            color: JitanColors.errorStrong,
            busy: _busy,
            onPressed: _deactivate,
          ),
        ],
      ),
    ],
  );
}

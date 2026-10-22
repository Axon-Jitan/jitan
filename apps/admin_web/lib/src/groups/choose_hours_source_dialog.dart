import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';

/// Opens "Choose where the hours come from" for [member]. Returns the group
/// chosen once the server saved it, or `null`.
Future<GroupSummary?> showChooseHoursSourceDialog(
  BuildContext context, {
  required ScheduleSourceApi api,
  required GroupMember member,
  required int suggestedGroupId,
}) => showJitanModal<GroupSummary>(
  context,
  builder: (_) => ChooseHoursSourceDialog(api: api, member: member, suggestedGroupId: suggestedGroupId),
);

/// "Schedules come from" for an employee in several groups (D3b): HR picks
/// the group whose work hours the employee works. The server switches the
/// employee's schedule over and audits it (`PUT …/schedule-source`); this
/// window only shows the choice. Made in the employee's first company: the
/// endpoint is company-scoped and the right is checked there.
class ChooseHoursSourceDialog extends StatefulWidget {
  const ChooseHoursSourceDialog({super.key, required this.api, required this.member, required this.suggestedGroupId});

  final ScheduleSourceApi api;
  final GroupMember member;

  /// Chosen at first: the group whose page HR came from.
  final int suggestedGroupId;

  @override
  State<ChooseHoursSourceDialog> createState() => _ChooseHoursSourceDialogState();
}

class _ChooseHoursSourceDialogState extends State<ChooseHoursSourceDialog> {
  List<GroupSummary>? _groups;
  int? _chosen;
  bool _busy = false;
  String? _messageKey;
  ApiClientException? _failure;

  int? get _companyId => widget.member.companyIds.firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyId = _companyId;
    if (companyId == null) return;
    try {
      final source = await widget.api.get(companyId, widget.member.id);
      if (!mounted) return;
      setState(() {
        _groups = source.groups;
        _chosen = source.sourceGroupId ??
            (source.groups.any((g) => g.id == widget.suggestedGroupId) ? widget.suggestedGroupId : null);
      });
    } on ApiClientException catch (failure) {
      if (mounted) setState(() => _failure = failure);
    }
  }

  Future<void> _save() async {
    final companyId = _companyId, chosen = _chosen;
    if (companyId == null || chosen == null) return;
    setState(() {
      _busy = true;
      _failure = null;
      _messageKey = null;
    });
    try {
      await widget.api.set(companyId, widget.member.id, chosen);
      if (mounted) Navigator.of(context).pop(_groups!.firstWhere((g) => g.id == chosen));
    } on ApiClientException catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // 409: the chosen group has no hours of its own to give.
        if (failure.statusCode == 409) {
          _messageKey = AdminTextKeys.groupDetailChooseNoHours;
        } else {
          _failure = failure;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final failure = _failure;
    return JitanModal(
      width: 520,
      title: context.t(AdminTextKeys.groupDetailChooseTitle),
      onClose: _busy ? null : () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(AdminTextKeys.groupDetailChooseText, args: {'name': widget.member.displayName}),
            style: JitanTextStyles.stateMessage.copyWith(fontSize: 14, color: JitanColors.ink),
          ),
          const SizedBox(height: 18),
          if (groups == null && failure == null)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (groups != null)
            for (final group in groups) ...[
              JitanOptionCard(
                title: group.name,
                selected: _chosen == group.id,
                indicator: JitanOptionIndicator.radio,
                height: 56,
                onTap: _busy ? null : () => setState(() => _chosen = group.id),
              ),
              const SizedBox(height: 10),
            ],
          if (_messageKey case final key?) ...[
            const SizedBox(height: 6),
            JitanInlineError(title: context.t(key)),
          ],
          if (failure != null) ...[
            const SizedBox(height: 6),
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
        JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _busy ? null : () => Navigator.of(context).pop()),
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.groupDetailChooseSave),
          busy: _busy,
          onPressed: _chosen == null || groups == null ? null : _save,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/web_text.dart';
import '../l10n/employee_web_text_keys.dart';

Future<void> showSwitchActivityDialog(
  BuildContext context, {
  required ActivityApi api,
  required MyActivity activity,
  required DateTime clock,
}) => showJitanModal<void>(
  context,
  builder: (_) => _SwitchActivityDialog(api: api, activity: activity, at: clock),
);

/// What are you working on? (Figma `1513:176`): one list, and a tap saves
/// it. Every active project can be chosen (D44), so a search narrows it; the
/// recently used ones come first.
class _SwitchActivityDialog extends StatefulWidget {
  const _SwitchActivityDialog({required this.api, required this.activity, required this.at});

  final ActivityApi api;
  final MyActivity activity;
  final DateTime at;

  @override
  State<_SwitchActivityDialog> createState() => _SwitchActivityDialogState();
}

class _SwitchActivityDialogState extends State<_SwitchActivityDialog> {
  bool _busy = false;
  bool _failed = false;
  String _search = '';

  CurrentActivity? get _current => widget.activity.current;

  Future<void> _go(ActivityKind kind, {int? projectId}) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.api.switchTo(SwitchActivityRequest(kind: kind, at: widget.at.toUtc(), projectId: projectId));
      if (mounted) Navigator.of(context).pop();
    } on ApiClientException {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  Widget _row({required String title, required String detail, required bool selected, required VoidCallback onTap}) => InkWell(
    onTap: _busy ? null : onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 14)),
                Text(detail, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check, size: 20, color: JitanColors.success),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final current = _current;
    final onTransport = current?.kind == ActivityKind.transport;
    return JitanModal(
      width: 480,
      title: context.t(EmployeeWebTextKeys.switchTitle),
      subtitle: context.t(EmployeeWebTextKeys.switchText),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 18,
        children: [
          if (activity.projects.isNotEmpty)
            JitanSearchField(
              hintText: context.t(EmployeeWebTextKeys.projectsSearch),
              onChanged: (value) => setState(() => _search = value),
            ),
          WebList(
            color: JitanColors.tableHeader,
            radius: 14,
            rows: [
              for (final project in WebText.matching(activity.projects, _search))
                _row(
                  title: project.name,
                  detail: WebText.project(context, project),
                  selected: project.id == current?.project?.id && !onTransport,
                  onTap: () =>
                      _go(project.isClient ? ActivityKind.clientOnSite : ActivityKind.internal, projectId: project.id),
                ),
              _row(
                title: context.t(EmployeeWebTextKeys.entryTransport),
                detail: context.t(EmployeeWebTextKeys.transportHint),
                selected: onTransport,
                onTap: () => _go(ActivityKind.transport, projectId: current?.project?.id),
              ),
            ],
          ),
          if (_failed) Text(context.t(EmployeeWebTextKeys.failed), style: JitanTextStyles.fieldError),
        ],
      ),
      actions: [
        JitanSecondaryButton(label: context.t(EmployeeWebTextKeys.close), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

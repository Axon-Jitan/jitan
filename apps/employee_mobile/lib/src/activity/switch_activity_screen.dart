import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/phone_widgets.dart';
import 'activity_controller.dart';
import 'activity_text.dart';
import 'choose_project_screen.dart';

/// Switch activity (Figma `1588:2`): a project and what they're doing on
/// it, travelling included. The workday goes on. The project is picked on
/// Choose a project.
class SwitchActivityScreen extends StatefulWidget {
  const SwitchActivityScreen({super.key, required this.controller, this.project});

  final ActivityController controller;

  /// Already chosen on Choose a project.
  final MyProject? project;

  @override
  State<SwitchActivityScreen> createState() => _SwitchActivityScreenState();
}

class _SwitchActivityScreenState extends State<SwitchActivityScreen> {
  late final _current = widget.controller.activity.current;
  late MyProject? _project =
      widget.project ?? _current?.project ?? widget.controller.activity.projects.where((p) => p.isRecent).firstOrNull;
  late ActivityKind? _kind = _current?.kind;
  bool _busy = false;
  bool _failed = false;

  List<ActivityKind> get _kinds => [
    if (_project?.isClient ?? false) ...[ActivityKind.clientOnSite, ActivityKind.clientInHouse],
    ActivityKind.internal,
    ActivityKind.transport,
  ];

  bool get _changed {
    final kind = _kind;
    if (kind == null || !_kinds.contains(kind)) return false;
    return kind != _current?.kind || _project?.id != _current?.project?.id;
  }

  Future<void> _choose() async {
    final chosen = await Navigator.of(context).push<MyProject>(
      MaterialPageRoute(
        builder: (_) => ChooseProjectScreen(
          projects: widget.controller.activity.projects,
          currentId: _current?.project?.id,
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _project = chosen;
      if (!_kinds.contains(_kind)) _kind = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.controller.switchTo(kind: _kind!, projectId: _project?.id);
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

  /// "Switch to Transport", or to the project when that changes; plain
  /// "Switch" while nothing has changed.
  String _buttonLabel(BuildContext context) {
    if (!_changed) return context.t(EmployeeTextKeys.activitySwitchShort);
    final what = _project != null && _project!.id != _current?.project?.id
        ? _project!.name
        : ActivityText.kind(context, _kind!);
    return context.t(EmployeeTextKeys.activitySwitchTo, args: {'what': what});
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      appBar: phoneAppBar(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(context.t(EmployeeTextKeys.activitySwitchTitle), style: JitanMobileTextStyles.pageTitle),
                      ),
                      const SizedBox(height: 6),
                      Text(context.t(EmployeeTextKeys.activitySwitchText), style: JitanMobileTextStyles.pageSubtitle),
                      const SizedBox(height: 24),
                      Text(context.t(EmployeeTextKeys.activityProject), style: JitanMobileTextStyles.label),
                      const SizedBox(height: 8),
                      PhoneListCard(
                        padding: EdgeInsets.zero,
                        children: [
                          if (project == null)
                            PhoneListRow(
                              title: context.t(EmployeeTextKeys.activityChooseProject),
                              titleStyle: JitanMobileTextStyles.rowText.copyWith(color: JitanColors.inkMuted),
                              trailing: const PhoneChevron(),
                              onTap: _busy ? null : _choose,
                            )
                          else
                            PhoneListRow(
                              title: project.name,
                              detail: ActivityText.project(context, project),
                              trailing: Text(
                                context.t(EmployeeTextKeys.activityChange),
                                style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 13),
                              ),
                              onTap: _busy ? null : _choose,
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(context.t(EmployeeTextKeys.activityKind), style: JitanMobileTextStyles.label),
                      const SizedBox(height: 8),
                      PhoneListCard(
                        padding: EdgeInsets.zero,
                        children: [
                          for (final kind in _kinds)
                            PhoneListRow(
                              title: ActivityText.kind(context, kind),
                              titleStyle: JitanMobileTextStyles.rowText,
                              selected: kind == _kind,
                              trailing: kind == _kind ? const PhoneCheck() : null,
                              onTap: _busy ? null : () => setState(() => _kind = kind),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_failed) ...[
                PhoneErrorNote(
                  title: context.t(EmployeeTextKeys.activitySwitchFailed),
                  message: context.t(EmployeeTextKeys.todayCheckConnection),
                ),
                const SizedBox(height: 12),
              ],
              JitanMobileButton(
                label: _buttonLabel(context),
                size: JitanMobileButtonSize.phone,
                busy: _busy,
                onPressed: _changed ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

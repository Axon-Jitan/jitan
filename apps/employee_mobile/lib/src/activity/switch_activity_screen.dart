import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_widgets.dart';
import '../widgets/mobile_widgets.dart';
import 'activity_controller.dart';
import 'activity_text.dart';
import 'choose_project_screen.dart';

/// Home / Switch activity (Figma `1088:2`, chosen `1109:269`): a project and
/// what they're doing on it, travelling included. The workday goes on. The
/// project is picked on Choose a project (Figma `1512:502`).
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

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final currentProject = current?.project;
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      appBar: AppBar(backgroundColor: JitanColors.warmWhite, elevation: 0, scrolledUnderElevation: 0),
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
                        child: Text(context.t(EmployeeTextKeys.activitySwitch), style: JitanMobileTextStyles.title),
                      ),
                      const SizedBox(height: 6),
                      Text(context.t(EmployeeTextKeys.activitySwitchText), style: JitanMobileTextStyles.body),
                      const SizedBox(height: 28),
                      if (currentProject != null && current != null) ...[
                        TodayEyebrow(context.t(EmployeeTextKeys.activityWorkingOn)),
                        const SizedBox(height: 8),
                        Text(currentProject.name, style: JitanMobileTextStyles.cardTitle),
                        const SizedBox(height: 2),
                        Text(ActivityText.kind(context, current.kind), style: JitanMobileTextStyles.cardText),
                        const SizedBox(height: 18),
                        const Divider(height: 1, color: JitanColors.inputBorder),
                        const SizedBox(height: 18),
                      ],
                      Text(context.t(EmployeeTextKeys.activityProject), style: JitanMobileTextStyles.fieldLabel),
                      const SizedBox(height: 8),
                      _ProjectField(project: _project, onTap: _choose),
                      const SizedBox(height: 20),
                      Text(context.t(EmployeeTextKeys.activityKind), style: JitanMobileTextStyles.fieldLabel),
                      const SizedBox(height: 8),
                      TodayCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (i, kind) in _kinds.indexed) ...[
                              if (i > 0) const Divider(height: 1, color: JitanColors.inputBorder),
                              InkWell(
                                onTap: () => setState(() => _kind = kind),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    spacing: 14,
                                    children: [
                                      RadioDot(selected: kind == _kind),
                                      Expanded(
                                        child: Text(
                                          ActivityText.kind(context, kind),
                                          style: kind == _kind ? JitanMobileTextStyles.cardTitle : JitanMobileTextStyles.body,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_failed) ...[
                TodayErrorBox(
                  title: context.t(EmployeeTextKeys.activitySwitchFailed),
                  message: context.t(EmployeeTextKeys.todayCheckConnection),
                ),
                const SizedBox(height: 12),
              ],
              Text(context.t(EmployeeTextKeys.activityDayGoesOn), style: JitanMobileTextStyles.cardText),
              const SizedBox(height: 14),
              JitanMobileButton(
                label: context.t(EmployeeTextKeys.activitySwitch),
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

/// The chosen project, or "Choose a project"; tapping opens the list.
class _ProjectField extends StatelessWidget {
  const _ProjectField({required this.project, required this.onTap});

  final MyProject? project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chosen = project;
    return Semantics(
      button: true,
      child: TodayCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chosen?.name ?? context.t(EmployeeTextKeys.activityChooseProject),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: chosen == null ? JitanMobileTextStyles.body : JitanMobileTextStyles.cardTitle,
                      ),
                      if (chosen != null) ...[
                        const SizedBox(height: 3),
                        Text(ActivityText.project(context, chosen), style: JitanMobileTextStyles.cardText),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

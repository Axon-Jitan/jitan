import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_widgets.dart';
import '../widgets/mobile_widgets.dart';
import 'activity_controller.dart';
import 'activity_text.dart';

/// Home / Switch activity (Figma `1088:2`, chosen `1109:269`): a project and
/// what they're doing on it. The workday goes on.
class SwitchActivityScreen extends StatefulWidget {
  const SwitchActivityScreen({super.key, required this.controller});

  final ActivityController controller;

  @override
  State<SwitchActivityScreen> createState() => _SwitchActivityScreenState();
}

class _SwitchActivityScreenState extends State<SwitchActivityScreen> {
  late final _current = widget.controller.activity.current;
  late MyProject? _project = _current?.project ?? widget.controller.currentProjects.firstOrNull;
  late ActivityKind? _kind = _current?.kind;
  bool _busy = false;
  bool _failed = false;

  List<ActivityKind> get _kinds => [
    if (_project?.isClient ?? false) ...[ActivityKind.clientOnSite, ActivityKind.clientInHouse],
    ActivityKind.internal,
  ];

  bool get _changed {
    final kind = _kind;
    if (kind == null || !_kinds.contains(kind)) return false;
    return kind != _current?.kind || _project?.id != _current?.project?.id;
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
    final projects = widget.controller.currentProjects;
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
                      JitanSelectField<int>(
                        label: context.t(EmployeeTextKeys.activityProject),
                        value: _project?.id,
                        options: [for (final p in projects) JitanSelectOption(value: p.id, label: p.name)],
                        onChanged: (id) => setState(() {
                          _project = projects.where((p) => p.id == id).firstOrNull;
                          if (!_kinds.contains(_kind)) _kind = null;
                        }),
                      ),
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

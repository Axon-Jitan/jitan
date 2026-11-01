import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/web_services.dart';
import '../common/web_text.dart';
import '../l10n/employee_web_text_keys.dart';
import 'project_dialog.dart';

/// Projects (Figma `1499:742`): current and earlier, as two plain lists.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.services});

  final WebServices services;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  MyActivity? _activity;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final activity = await widget.services.activity.mine();
      if (mounted) setState(() => _activity = activity);
    } on ApiClientException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Widget _section(BuildContext context, String title, List<MyProject> projects) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Text(title, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 15)),
      WebList(
        rows: [
          for (final project in projects)
            InkWell(
              onTap: () => showProjectDialog(context, project: project),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          Text(project.name, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 14)),
                          Text(
                            project.isCurrent ? WebText.project(context, project) : '${project.statusName ?? ''} · ${project.companyName}',
                            overflow: TextOverflow.ellipsis,
                            style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
                  ],
                ),
              ),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_failed) return WebNoConnection(onRetry: _load);
    final activity = _activity;
    if (activity == null) return JitanLoadingState(label: context.t(EmployeeWebTextKeys.loading));
    final current = activity.projects.where((p) => p.isCurrent).toList();
    final earlier = activity.projects.where((p) => !p.isCurrent).toList();
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return SingleChildScrollView(
      padding: EdgeInsets.all(phone ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          JitanPageHeader(
            title: context.t(EmployeeWebTextKeys.projectsTitle),
            subtitle: context.t(EmployeeWebTextKeys.projectsSubtitle),
          ),
          if (activity.projects.isEmpty) Text(context.t(EmployeeWebTextKeys.projectsNone), style: JitanTextStyles.stateMessage),
          if (current.isNotEmpty) _section(context, context.t(EmployeeWebTextKeys.projectsCurrent), current),
          if (earlier.isNotEmpty) _section(context, context.t(EmployeeWebTextKeys.projectsEarlier), earlier),
        ],
      ),
    );
  }
}

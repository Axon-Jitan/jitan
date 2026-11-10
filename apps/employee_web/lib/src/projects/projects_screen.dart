import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/web_services.dart';
import '../common/web_text.dart';
import '../l10n/employee_web_text_keys.dart';

/// Projects (Figma `1499:742`, as the phone's Choose a project `1512:502`):
/// every active project (D44), searched by SAP number or name, the recently
/// used ones first.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.services});

  final WebServices services;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  MyActivity? _activity;
  bool _failed = false;
  String _search = '';

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

  Widget _section(BuildContext context, String title, List<MyProject> projects, int? currentId) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Text(title, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 15)),
      WebList(
        rows: [
          for (final project in projects)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        Text(project.name, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 14)),
                        Text(
                          WebText.project(context, project),
                          overflow: TextOverflow.ellipsis,
                          style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  if (project.id == currentId)
                    Text(
                      context.t(EmployeeWebTextKeys.projectsNow),
                      style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.success),
                    ),
                ],
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
    final matching = WebText.matching(activity.projects, _search);
    final recent = [
      for (final p in matching)
        if (p.isRecent) p,
    ];
    final others = [
      for (final p in matching)
        if (!p.isRecent) p,
    ];
    final currentId = activity.current?.project?.id;
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
          if (activity.projects.isEmpty)
            Text(context.t(EmployeeWebTextKeys.projectsNone), style: JitanTextStyles.stateMessage)
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: JitanSearchField(
                  hintText: context.t(EmployeeWebTextKeys.projectsSearch),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
            ),
            if (matching.isEmpty) Text(context.t(EmployeeWebTextKeys.projectsNoMatch), style: JitanTextStyles.stateMessage),
            if (recent.isNotEmpty) _section(context, context.t(EmployeeWebTextKeys.projectsRecent), recent, currentId),
            if (others.isNotEmpty) _section(context, context.t(EmployeeWebTextKeys.projectsAll), others, currentId),
          ],
        ],
      ),
    );
  }
}

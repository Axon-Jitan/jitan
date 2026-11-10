import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import '../locations/location_map.dart';
import 'project_dialog.dart';
import 'projects_controller.dart';
import 'projects_table.dart';

/// HR/Admin "Projects" (Figma `1512:2`, D43, D44): what employees can choose
/// to work on, added by HR until SAP is connected. A row opens its form.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.api, required this.locationsApi, required this.maps, this.clock});

  final ProjectsApi api;

  /// The workshops an internal project can sit at.
  final LocationsApi locationsApi;
  final LocationMaps? maps;
  final DateTime Function()? clock;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late final _controller = ProjectsController(widget.api)..load();

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open([ProjectSummary? project]) async {
    final changed = await showProjectDialog(
      context,
      api: widget.api,
      locationsApi: widget.locationsApi,
      maps: widget.maps,
      projectId: project?.id,
    );
    if (changed) await _controller.load();
  }

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JitanPageHeader(
          title: context.t(AdminTextKeys.projectsTitle),
          subtitle: context.t(AdminTextKeys.projectsSubtitle),
          action: JitanPrimaryButton(
            label: context.t(AdminTextKeys.projectAdd),
            height: JitanDimensions.controlHeight,
            onPressed: _open,
          ),
        ),
        const SizedBox(height: JitanDimensions.headerToToolbar),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: JitanSearchField(
              clearTooltip: context.t(CommonTextKeys.searchClear),
              outlined: true,
              hintText: context.t(AdminTextKeys.projectsSearch),
              onChanged: _controller.updateSearch,
            ),
          ),
        ),
        const SizedBox(height: JitanDimensions.toolbarToTable),
      ],
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  Widget _content(BuildContext context) => switch (_controller.state) {
    ProjectsLoading() => _state(GroupStateText(context.t(AdminTextKeys.projectsLoading))),
    ProjectsFailed() => _state(GroupStateText(context.t(AdminTextKeys.projectsLoadFailed), onRetry: _controller.load)),
    ProjectsLoaded(projects: []) => _state(GroupStateText(context.t(AdminTextKeys.projectsEmpty))),
    ProjectsLoaded() => switch (_controller.visible) {
      [] => _state(GroupStateText(context.t(AdminTextKeys.projectsNoMatch))),
      final projects => ProjectsTable(projects: projects, now: _now, onOpen: _open),
    },
  };

  static Widget _state(Widget child) => SliverToBoxAdapter(child: child);
}

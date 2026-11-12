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

/// HR/Admin "Projects" (Figma `HR / Projects V2 — page` `1562:2`, D43, D44):
/// what employees can choose to work on, added by HR until SAP is
/// connected. A row opens the project; nothing yet, no match, loading and
/// error as on the other lists.
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

  /// The pop-up says what was saved itself; the list reloads after.
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

  bool get _isEmpty => switch (_controller.state) {
    ProjectsLoaded(projects: []) => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JitanPageHeader(
            title: context.t(AdminTextKeys.projectsTitle),
            subtitle: switch (_controller.state) {
              ProjectsLoaded(:final projects) when projects.isNotEmpty => context.tPlural(AdminTextKeys.projectsCount, projects.length),
              _ => context.t(AdminTextKeys.projectsSubtitle),
            },
            action: _isEmpty
                ? null
                : JitanPrimaryButton(
                    label: context.t(AdminTextKeys.projectAdd),
                    icon: Icons.add,
                    height: JitanDimensions.controlHeight,
                    onPressed: _open,
                  ),
          ),
          const SizedBox(height: JitanDimensions.headerToToolbar),
          if (!_isEmpty) ...[_toolbar(context), const SizedBox(height: JitanDimensions.toolbarToTable)],
        ],
      ),
    ),
    list: [ListenableBuilder(listenable: _controller, builder: (context, _) => _content(context))],
  );

  /// A search box and All · Active · Inactive, as on Locations.
  Widget _toolbar(BuildContext context) {
    final search = JitanSearchField(
      clearTooltip: context.t(CommonTextKeys.searchClear),
      outlined: true,
      hintText: context.t(AdminTextKeys.projectsSearch),
      onChanged: _controller.updateSearch,
    );
    final status = JitanPillSwitch<ProjectStatusFilter?>(
      options: [
        (null, context.t(AdminTextKeys.projectsFilterAll)),
        (ProjectStatusFilter.active, context.t(CommonTextKeys.statusActive)),
        (ProjectStatusFilter.inactive, context.t(CommonTextKeys.statusInactive)),
      ],
      value: _controller.status,
      onChanged: _controller.updateStatus,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [search, status])
          : Row(spacing: 12, children: [SizedBox(width: 320, child: search), status]),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    ProjectsLoading() => _line(GroupStateText(context.t(AdminTextKeys.projectsLoading))),
    ProjectsFailed() => _line(GroupStateText(context.t(AdminTextKeys.projectsLoadFailed), onRetry: _controller.load)),
    ProjectsLoaded(projects: []) => SliverToBoxAdapter(
      child: JitanEmptyPage(
        title: context.t(AdminTextKeys.projectsEmptyTitle),
        message: context.t(AdminTextKeys.projectsEmpty),
        actionLabel: context.t(AdminTextKeys.projectAdd),
        onAction: _open,
      ),
    ),
    ProjectsLoaded() => switch (_controller.visible) {
      [] => SliverToBoxAdapter(child: _nothingShown(context)),
      final projects => ProjectsTable(projects: projects, now: _now, onOpen: _open),
    },
  };

  /// Nothing to show, said for what HR did: a search or a status.
  Widget _nothingShown(BuildContext context) {
    final (title, message) = switch ((_controller.search, _controller.status)) {
      ('', ProjectStatusFilter.inactive) => (AdminTextKeys.projectsNoInactiveTitle, AdminTextKeys.projectsNoInactiveText),
      ('', ProjectStatusFilter.active) => (AdminTextKeys.projectsNoActiveTitle, AdminTextKeys.projectsNoActiveText),
      _ => (AdminTextKeys.projectsNoMatchTitle, AdminTextKeys.projectsNoMatch),
    };
    return JitanNoResults(title: context.t(title), message: context.t(message));
  }

  static Widget _line(Widget child) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 4), child: child));
}

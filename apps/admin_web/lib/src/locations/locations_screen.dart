import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'deactivate_location_dialog.dart';
import 'location_dialog.dart';
import 'location_map.dart';
import 'locations_controller.dart';
import 'locations_table.dart';

/// HR/Admin "Locations" page (Figma `1542:2`; no results `1543:114`, none
/// inactive `1543:216`, nothing yet `1543:318`). The ERD has no company on an
/// address (GAP-03), so this page is not company-scoped.
class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key, required this.api, required this.maps, this.startAdding = false});

  final LocationsApi api;

  /// Opens Add location at once (Add location after adding a company).
  final bool startAdding;

  /// `null` when the build has no Mapbox token.
  final LocationMaps? maps;

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  late final _controller = LocationsController(widget.api)..load();

  @override
  void initState() {
    super.initState();
    if (widget.startAdding) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _open();
        // Then drop "?add=new", so a reload doesn't open it again.
        if (mounted) unawaited(GoRouter.maybeOf(context)?.replace<void>(AdminRoutes.locations));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String text) => showJitanToast(context, text);

  Future<void> _open([Location? location]) async {
    final result = await showLocationDialog(context, api: widget.api, maps: widget.maps, location: location);
    if (result == null || !mounted) return;
    switch (result) {
      case LocationSaved(location: final saved):
        _say(context.t(location == null ? AdminTextKeys.locationAdded : AdminTextKeys.locationUpdated, args: {'location': saved.name}));
      case LocationReactivated(location: final done):
        _say(context.t(AdminTextKeys.locationReactivated, args: {'location': done.name}));
      case LocationDeactivateChosen():
        final done = await showDeactivateLocationDialog(context, api: widget.api, location: location!);
        if (done == null || !mounted) return;
        _say(context.t(AdminTextKeys.locationDeactivated, args: {'location': done.name}));
    }
    await _controller.load();
  }

  bool get _isEmpty => switch (_controller.state) {
    LocationsLoaded(locations: []) => true,
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
            title: context.t(AdminTextKeys.locationsTitle),
            subtitle: switch (_controller.state) {
              LocationsLoaded(:final locations) when locations.isNotEmpty =>
                context.tPlural(AdminTextKeys.locationsCount, locations.length),
              _ => context.t(AdminTextKeys.locationsSubtitle),
            },
            action: _isEmpty
                ? null
                : JitanPrimaryButton(
                    label: context.t(AdminTextKeys.locationAdd),
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

  /// A search box and All · Active · Inactive, as on Companies.
  Widget _toolbar(BuildContext context) {
    final search = JitanSearchField(
      clearTooltip: context.t(CommonTextKeys.searchClear),
      outlined: true,
      hintText: context.t(AdminTextKeys.locationsSearch),
      onChanged: _controller.updateSearch,
    );
    final status = JitanPillSwitch<LocationStatusFilter?>(
      options: [
        (null, context.t(AdminTextKeys.locationsFilterAll)),
        (LocationStatusFilter.active, context.t(CommonTextKeys.statusActive)),
        (LocationStatusFilter.inactive, context.t(CommonTextKeys.statusInactive)),
      ],
      value: _controller.status,
      onChanged: _controller.updateStatus,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [search, status],
            )
          : Row(
              spacing: 12,
              children: [SizedBox(width: 320, child: search), status],
            ),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    LocationsLoading() => _centered(JitanLoadingState(label: context.t(AdminTextKeys.locationsLoading))),
    LocationsFailed() => _state(GroupStateText(context.t(AdminTextKeys.locationsLoadFailed), onRetry: _controller.load)),
    LocationsLoaded(locations: []) => SliverToBoxAdapter(
      child: JitanEmptyPage(
        title: context.t(AdminTextKeys.locationsEmptyTitle),
        message: context.t(AdminTextKeys.locationsEmptyText),
        actionLabel: context.t(AdminTextKeys.locationAdd),
        onAction: _open,
      ),
    ),
    LocationsLoaded() => switch (_controller.visible) {
      [] => SliverToBoxAdapter(child: _nothingShown(context)),
      final locations => LocationsTable(locations: locations, onOpen: _open),
    },
  };

  /// Nothing to show: said for what HR did, a search or a status
  /// (Figma `1543:114`, `1543:216`), calmly on the page itself.
  Widget _nothingShown(BuildContext context) {
    final (title, line) = switch ((_controller.search, _controller.status)) {
      ('', LocationStatusFilter.inactive) => (AdminTextKeys.locationsNoInactiveTitle, AdminTextKeys.locationsNoInactiveText),
      ('', LocationStatusFilter.active) => (AdminTextKeys.locationsNoActiveTitle, AdminTextKeys.locationsNoActiveText),
      _ => (AdminTextKeys.locationsNoMatchTitle, AdminTextKeys.locationsNoMatchText),
    };
    return JitanNoResults(title: context.t(title), message: context.t(line));
  }

  static Widget _centered(Widget child) => JitanTableStateSliver(child: child);

  static Widget _state(Widget child) => SliverToBoxAdapter(
    child: Padding(padding: const EdgeInsets.only(top: 20), child: child),
  );
}

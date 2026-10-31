import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'deactivate_location_dialog.dart';
import 'location_dialog.dart';
import 'location_map.dart';
import 'locations_controller.dart';
import 'locations_empty_card.dart';
import 'locations_table.dart';

/// HR/Admin "Locations" page (Figma `1465:2`, empty `1465:177`). The ERD has
/// no company on an address yet (GAP-03), so this page is not company-scoped.
class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key, required this.api, required this.maps});

  final LocationsApi api;

  /// `null` when the build has no Mapbox token.
  final LocationMaps? maps;

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  late final _controller = LocationsController(widget.api)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

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
            subtitle: context.t(AdminTextKeys.locationsSubtitle),
            action: _isEmpty
                ? null
                : JitanPrimaryButton(
                    label: context.t(AdminTextKeys.locationAdd),
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

  Widget _toolbar(BuildContext context) {
    final search = JitanFieldLabel(
      label: context.t(CommonTextKeys.searchLabel),
      child: JitanSearchField(
        clearTooltip: context.t(CommonTextKeys.searchClear),
        outlined: true,
        hintText: context.t(AdminTextKeys.locationsSearch),
        onChanged: _controller.updateSearch,
      ),
    );
    final status = JitanSelectField<LocationStatusFilter?>(
      label: context.t(AdminTextKeys.scheduleFilterStatus),
      value: _controller.status,
      options: [
        JitanSelectOption(value: null, label: context.t(AdminTextKeys.locationsFilterAll)),
        JitanSelectOption(value: LocationStatusFilter.active, label: context.t(CommonTextKeys.statusActive)),
        JitanSelectOption(value: LocationStatusFilter.inactive, label: context.t(CommonTextKeys.statusInactive)),
      ],
      onChanged: _controller.updateStatus,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 14), status],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(width: JitanDimensions.filterSearchWidth, child: search),
                const SizedBox(width: 16),
                SizedBox(width: 220, child: status),
              ],
            ),
    );
  }

  Widget _content(BuildContext context) => switch (_controller.state) {
    LocationsLoading() => _state(GroupStateText(context.t(AdminTextKeys.locationsLoading))),
    LocationsFailed() => _state(GroupStateText(context.t(AdminTextKeys.locationsLoadFailed), onRetry: _controller.load)),
    LocationsLoaded(locations: []) => SliverToBoxAdapter(child: LocationsEmptyCard(onAdd: _open)),
    LocationsLoaded() => switch (_controller.visible) {
      [] => _state(GroupStateText(context.t(AdminTextKeys.locationsNoMatch))),
      final locations => LocationsTable(locations: locations, onOpen: _open),
    },
  };

  static Widget _state(Widget child) => SliverToBoxAdapter(
    child: Padding(padding: const EdgeInsets.only(top: 20), child: child),
  );
}

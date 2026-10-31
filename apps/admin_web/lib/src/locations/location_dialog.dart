import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'location_area_control.dart';
import 'location_form_controller.dart';
import 'location_map.dart';

/// How the location dialog ended.
sealed class LocationDialogResult {
  const LocationDialogResult();
}

class LocationSaved extends LocationDialogResult {
  const LocationSaved(this.location);

  final Location location;
}

class LocationReactivated extends LocationDialogResult {
  const LocationReactivated(this.location);

  final Location location;
}

/// "Deactivate" was chosen: the page asks to confirm.
class LocationDeactivateChosen extends LocationDialogResult {
  const LocationDeactivateChosen();
}

/// Opens Add location, or Edit location for [location].
Future<LocationDialogResult?> showLocationDialog(
  BuildContext context, {
  required LocationsApi api,
  required LocationMaps? maps,
  Location? location,
}) => showJitanModal<LocationDialogResult>(
  context,
  builder: (_) => LocationDialog(api: api, maps: maps, location: location),
);

/// Figma `HR / Locations — Add location` (1465:301), `name in use` (1465:482)
/// and `Edit location` (1465:664): the form beside the map; stacked on a phone.
class LocationDialog extends StatefulWidget {
  const LocationDialog({super.key, required this.api, required this.maps, this.location});

  final LocationsApi api;
  final LocationMaps? maps;
  final Location? location;

  @override
  State<LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<LocationDialog> {
  static const _width = 900.0;
  static const _height = 600.0;
  static const _formWidth = 440.0;
  static const _phoneMapHeight = 340.0;
  static const _radius = 24.0;

  late final _form = LocationFormController(
    api: widget.api,
    location: widget.location,
    geocoder: widget.maps?.geocoder,
  );
  bool _reactivating = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await _form.save();
    if (saved != null && mounted) Navigator.of(context).pop(LocationSaved(saved));
  }

  Future<void> _reactivate() async {
    setState(() => _reactivating = true);
    try {
      final done = await widget.api.reactivate(widget.location!.id);
      if (mounted) Navigator.of(context).pop(LocationReactivated(done));
    } on ApiClientException catch (failure) {
      if (!mounted) return;
      _form.failure = failure;
      setState(() => _reactivating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: JitanColors.surface,
    surfaceTintColor: JitanColors.surface,
    insetPadding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
    child: ListenableBuilder(
      listenable: _form,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < _width
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fields(context),
                    SizedBox(height: _phoneMapHeight, child: _map(context)),
                    Padding(padding: const EdgeInsets.all(20), child: _actions(context)),
                  ],
                ),
              )
            : SizedBox(
                width: _width,
                height: _height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: _formWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: SingleChildScrollView(child: _fields(context))),
                          Padding(padding: const EdgeInsets.fromLTRB(28, 8, 28, 24), child: _actions(context)),
                        ],
                      ),
                    ),
                    Expanded(child: _map(context)),
                  ],
                ),
              ),
      ),
    ),
  );

  Widget _fields(BuildContext context) {
    final editing = widget.location != null;
    final enabled = !_form.busy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      // Tab follows the form's order: reading order mixes up the short fields.
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.t(editing ? AdminTextKeys.locationEditTitle : AdminTextKeys.locationAddTitle),
                style: JitanTextStyles.modalTitle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.t(editing ? AdminTextKeys.locationEditSubtitle : AdminTextKeys.locationAddSubtitle),
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
            const SizedBox(height: 24),
            JitanTextField(
              label: context.t(AdminTextKeys.locationFieldName),
              controller: _form.name,
              enabled: enabled,
              autofocus: !editing,
              hintText: context.t(AdminTextKeys.locationFieldNameHint),
              maxLength: LocationRequest.maxNameLength,
              errorText: _form.nameError == null ? null : context.t(_form.nameError!),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: JitanTextField(
                    label: context.t(AdminTextKeys.locationFieldStreet),
                    controller: _form.street,
                    enabled: enabled,
                    maxLength: LocationRequest.maxStreetLength,
                    errorText: _form.streetError == null ? null : context.t(_form.streetError!),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 72,
                  child: JitanTextField(
                    label: context.t(AdminTextKeys.locationFieldNumber),
                    controller: _form.number,
                    enabled: enabled,
                    maxLength: LocationRequest.maxNumberLength,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: JitanTextField(
                    label: context.t(AdminTextKeys.locationFieldBox),
                    controller: _form.box,
                    enabled: enabled,
                    maxLength: LocationRequest.maxBoxLength,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: JitanTextField(
                    label: context.t(AdminTextKeys.locationFieldPostcode),
                    controller: _form.zipcode,
                    enabled: enabled,
                    maxLength: LocationRequest.maxZipcodeLength,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: JitanTextField(
                    label: context.t(AdminTextKeys.locationFieldCity),
                    controller: _form.city,
                    enabled: enabled,
                    maxLength: LocationRequest.maxCityLength,
                    onSubmitted: (_) {
                      if (_form.canSave) _save();
                    },
                  ),
                ),
              ],
            ),
            if (_form.failure case final failure?) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final keys = failureTextKeysFor(failure);
                  return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final location = widget.location;
    final idle = !_form.busy && !_reactivating;
    final quiet = location == null
        ? null
        : TextButton(
            style: TextButton.styleFrom(foregroundColor: JitanColors.inkMuted, padding: EdgeInsets.zero),
            onPressed: !idle
                ? null
                : location.isActive
                ? () => Navigator.of(context).pop(const LocationDeactivateChosen())
                : _reactivate,
            child: Text(context.t(location.isActive ? AdminTextKeys.locationDeactivate : AdminTextKeys.locationReactivate)),
          );
    // Wraps instead of overflowing: on a phone Deactivate takes its own line.
    final buttons = Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        JitanSecondaryButton(
          label: context.t(CommonTextKeys.cancel),
          onPressed: idle ? () => Navigator.of(context).pop() : null,
        ),
        JitanPrimaryButton(
          label: context.t(location == null ? AdminTextKeys.locationAdd : AdminTextKeys.locationSave),
          busy: _form.busy,
          onPressed: _form.canSave && idle ? _save : null,
        ),
      ],
    );
    return Wrap(
      alignment: quiet == null ? WrapAlignment.end : WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [?quiet, buttons],
    );
  }

  Widget _map(BuildContext context) {
    final maps = widget.maps;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (maps == null)
          ColoredBox(
            color: JitanColors.warmWhite,
            child: Center(
              child: Text(context.t(AdminTextKeys.locationMapNotSetUp), style: JitanTextStyles.stateMessage),
            ),
          )
        else
          maps.map(_form.point, _form.radiusMeters, _form.placePin),
        Positioned(
          top: 20,
          left: 20,
          child: _Hint(context.t(_form.point == null ? AdminTextKeys.locationMapPlace : AdminTextKeys.locationMapDrag)),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: Material(
            color: JitanColors.surface,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              iconSize: 16,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              onPressed: _form.busy ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: JitanColors.ink),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: LocationAreaControl(
            meters: _form.radiusMeters,
            onChanged: _form.busy ? null : _form.setRadius,
          ),
        ),
        const Positioned(left: 22, bottom: 8, child: Text(_attribution, style: TextStyle(fontSize: 9, color: JitanColors.inkMuted))),
      ],
    );
  }

  /// Required by Mapbox, in every language.
  static const _attribution = '© Mapbox © OpenStreetMap';
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: JitanColors.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 12)),
  );
}

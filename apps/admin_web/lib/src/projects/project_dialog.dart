import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import '../locations/location_form_controller.dart';
import '../locations/location_map.dart';
import '../locations/location_map_panel.dart';
import 'project_workshop_map.dart';

/// Opens Add project, or Edit project for [projectId]. Returns `true` when
/// something was saved.
Future<bool> showProjectDialog(
  BuildContext context, {
  required ProjectsApi api,
  required LocationsApi locationsApi,
  required LocationMaps? maps,
  int? projectId,
}) async =>
    await showJitanModal<bool>(
      context,
      barrierDismissible: false,
      builder: (_) => ProjectDialog(api: api, locationsApi: locationsApi, maps: maps, projectId: projectId),
    ) ??
    false;

/// Figma `HR / Projects V2`: a project (`1562:101`), our workshop
/// (`1562:350`), inactive (`1562:789`). The project by name, the kind, the
/// SAP number and name, then the address beside the map with its pin and
/// area, or the workshop with its own area shown read-only: one size for
/// both kinds, so switching never makes the pop-up jump. Save waits for a
/// change; Deactivate asks first (`1562:605`), Reactivate does not.
class ProjectDialog extends StatefulWidget {
  const ProjectDialog({super.key, required this.api, required this.locationsApi, required this.maps, this.projectId});

  final ProjectsApi api;
  final LocationsApi locationsApi;
  final LocationMaps? maps;
  final int? projectId;

  @override
  State<ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<ProjectDialog> {
  static const _width = 900.0;
  static const _height = 600.0;
  static const _formWidth = 440.0;
  static const _phoneMapHeight = 340.0;
  static const _radius = 24.0;

  final _sap = TextEditingController();
  final _name = TextEditingController();
  LocationFormController? _site;
  ProjectDetails? _details;
  List<Location> _workshops = const [];
  bool _clientSite = true;
  int? _workshopId;
  bool _loading = true;
  bool _busy = false;
  /// Something was saved (deactivated, reactivated): the list reloads.
  bool _saved = false;
  ApiClientException? _failure;
  final _errors = <String, String>{};

  bool get _editing => widget.projectId != null;

  @override
  void initState() {
    super.initState();
    _sap.addListener(_refresh);
    _name.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _sap.dispose();
    _name.dispose();
    _site?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final workshops = [
        for (final l in await widget.locationsApi.list())
          if (l.isActive && l.point != null) l,
      ];
      final id = widget.projectId;
      final details = id == null ? null : await widget.api.find(id);
      if (!mounted) return;
      setState(() {
        _workshops = workshops;
        _details = details;
        _sap.text = details?.summary.sapNumber ?? '';
        _name.text = details?.summary.name ?? '';
        _clientSite = details?.summary.isClientSite ?? true;
        _workshopId = details?.workshopId ?? (workshops.length == 1 ? workshops.single.id : null);
        _site = LocationFormController(api: widget.locationsApi, location: details?.site, geocoder: widget.maps?.geocoder)
          ..addListener(_refresh);
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (mounted) {
        setState(() {
          _failure = e;
          _loading = false;
        });
      }
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _canSave {
    if (_busy || _sap.text.trim().isEmpty || _name.text.trim().isEmpty) return false;
    return _clientSite ? _site?.hasPlace ?? false : _workshopId != null;
  }

  /// Something differs from the stored project (always true when adding).
  bool get _changed {
    final details = _details;
    if (details == null) return true;
    if (_sap.text.trim() != details.summary.sapNumber.trim() || _name.text.trim() != details.summary.name.trim()) return true;
    return _clientSite ? _site?.changed ?? false : _workshopId != details.workshopId;
  }

  Location? get _workshop => _workshops.where((w) => w.id == _workshopId).firstOrNull;

  Future<void> _save() async {
    final sap = _sap.text, name = _name.text;
    final site = _clientSite ? _site?.request(ProjectRequest.fullName(sap.trim(), name.trim())) : null;
    final request = ProjectRequest(sapNumber: sap, name: name, site: site, workshopId: _clientSite ? null : _workshopId);
    setState(() {
      _busy = true;
      _failure = null;
      _errors.clear();
    });
    try {
      final id = widget.projectId;
      final saved = id == null ? await widget.api.create(request) : await widget.api.update(id, request);
      if (!mounted) return;
      showJitanToast(
        context,
        context.t(id == null ? AdminTextKeys.projectAdded : AdminTextKeys.projectSaved, args: {'project': saved.summary.fullName}),
      );
      Navigator.of(context).pop(true);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (e.error) {
          case ApiError(code: ApiErrorCode.duplicateLocationName):
            _errors[ProjectRequest.fieldName] = AdminTextKeys.projectErrorNameTaken;
          case ApiError(code: ApiErrorCode.validationFailed, field: ProjectRequest.fieldSapNumber):
            _errors[ProjectRequest.fieldSapNumber] = AdminTextKeys.projectErrorSapNumber;
          case ApiError(code: ApiErrorCode.validationFailed, field: ProjectRequest.fieldName):
            _errors[ProjectRequest.fieldName] = AdminTextKeys.projectErrorName;
          case ApiError(code: ApiErrorCode.validationFailed, field: ProjectRequest.fieldWorkshop):
            _errors[ProjectRequest.fieldWorkshop] = AdminTextKeys.projectErrorWorkshop;
          default:
            _failure = e;
        }
      });
    }
  }

  /// Deactivate (after asking) or Reactivate; said once the server
  /// confirmed, and the pop-up closes.
  Future<void> _toggleActive() async {
    final details = _details!;
    final active = details.summary.isActive;
    if (active && !await confirmProjectDeactivate(context, details.summary)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final id = details.summary.id;
      final saved = active ? await widget.api.deactivate(id) : await widget.api.reactivate(id);
      if (!mounted) return;
      _saved = true;
      showJitanToast(
        context,
        context.t(active ? AdminTextKeys.projectDeactivated : AdminTextKeys.projectReactivated, args: {'project': saved.summary.fullName}),
      );
      Navigator.of(context).pop(true);
    } on ApiClientException catch (e) {
      if (mounted) {
        setState(() {
          _failure = e;
          _busy = false;
        });
      }
    }
  }

  String? _error(String field) {
    final key = _errors[field];
    return key == null ? null : context.t(key);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: JitanColors.surface,
    surfaceTintColor: JitanColors.surface,
    insetPadding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final site = _site;
        // The right half: the client site's pin and area, or the workshop's,
        // so the pop-up is one size for both kinds.
        final Widget map = _loading
            ? const ColoredBox(color: JitanColors.warmWhite)
            : _clientSite && site != null
            ? LocationMapPanel(form: site, maps: widget.maps, busy: _busy, showClose: false)
            : ProjectWorkshopMap(workshop: _workshop, maps: widget.maps);
        if (constraints.maxWidth < _width) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fields(context),
                SizedBox(height: _phoneMapHeight, child: map),
                Padding(padding: const EdgeInsets.all(20), child: _actions(context)),
              ],
            ),
          );
        }
        return SizedBox(
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
              Expanded(child: map),
            ],
          ),
        );
      },
    ),
  );

  /// "P-1063 Warehouse upgrade" and its status when editing; the kind's
  /// sentence when adding.
  (String, String) _heading(BuildContext context) {
    final details = _details;
    if (details == null) {
      return (
        context.t(AdminTextKeys.projectAddTitle),
        context.t(_clientSite ? AdminTextKeys.projectClientText : AdminTextKeys.projectWorkshopText),
      );
    }
    final active = details.summary.isActive;
    return (
      details.summary.fullName,
      context.t(
        active ? AdminTextKeys.projectStatusActiveLine : AdminTextKeys.projectStatusInactiveLine,
        args: {'kind': context.t(_clientSite ? AdminTextKeys.projectKindClient : AdminTextKeys.projectKindWorkshop)},
      ),
    );
  }

  Widget _fields(BuildContext context) {
    final enabled = !_busy && !_loading;
    final site = _site;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(_heading(context).$1, style: JitanTextStyles.modalTitle)),
            const SizedBox(height: 4),
            Text(_heading(context).$2, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
            const SizedBox(height: 24),
            if (_loading)
              JitanLoadingState(label: context.t(AdminTextKeys.projectsLoading))
            else ...[
              JitanSegmentedSwitch<bool>(
                options: [
                  (true, context.t(AdminTextKeys.projectKindClient)),
                  (false, context.t(AdminTextKeys.projectKindWorkshop)),
                ],
                value: _clientSite,
                // A project keeps its kind once added.
                onChanged: _editing || !enabled ? null : (client) => setState(() => _clientSite = client),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: JitanTextField(
                      label: context.t(AdminTextKeys.projectSapNumber),
                      controller: _sap,
                      enabled: enabled,
                      autofocus: !_editing,
                      maxLength: ProjectRequest.maxSapNumberLength,
                      errorText: _error(ProjectRequest.fieldSapNumber),
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: JitanTextField(
                      label: context.t(AdminTextKeys.projectName),
                      controller: _name,
                      enabled: enabled,
                      maxLength: ProjectRequest.maxFullNameLength,
                      errorText: _error(ProjectRequest.fieldName),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_clientSite && site != null)
                ..._address(context, site, enabled)
              else ...[
                JitanSelectField<int>(
                  label: context.t(AdminTextKeys.projectWorkshop),
                  value: _workshopId,
                  hintText: context.t(AdminTextKeys.projectChoose),
                  errorText: _error(ProjectRequest.fieldWorkshop),
                  options: [for (final w in _workshops) JitanSelectOption(value: w.id, label: w.name)],
                  onChanged: enabled ? (id) => setState(() => _workshopId = id) : null,
                ),
                const SizedBox(height: 10),
                Text(context.t(AdminTextKeys.projectWorkshopHint), style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
              ],
            ],
            if (_failure case final failure?) ...[
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

  /// The client site's address: the Add location fields (Figma `1465:301`).
  List<Widget> _address(BuildContext context, LocationFormController site, bool enabled) => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: JitanTextField(
            label: context.t(AdminTextKeys.locationFieldStreet),
            controller: site.street,
            enabled: enabled,
            maxLength: LocationRequest.maxStreetLength,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: JitanTextField(
            label: context.t(AdminTextKeys.locationFieldNumber),
            controller: site.number,
            enabled: enabled,
            maxLength: LocationRequest.maxNumberLength,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: JitanTextField(
            label: context.t(AdminTextKeys.locationFieldBox),
            controller: site.box,
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
            controller: site.zipcode,
            enabled: enabled,
            maxLength: LocationRequest.maxZipcodeLength,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: JitanTextField(
            label: context.t(AdminTextKeys.locationFieldCity),
            controller: site.city,
            enabled: enabled,
            maxLength: LocationRequest.maxCityLength,
          ),
        ),
      ],
    ),
  ];

  Widget _actions(BuildContext context) {
    final details = _details;
    final idle = !_busy && !_loading;
    // Deactivate in red, Reactivate in ink (as on a location).
    final color = details?.summary.isActive ?? true ? JitanColors.errorStrong : JitanColors.ink;
    final quiet = details == null
        ? null
        : TextButton(
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              minimumSize: Size.zero,
            ),
            onPressed: idle ? _toggleActive : null,
            child: Text(
              context.t(details.summary.isActive ? AdminTextKeys.projectDeactivate : AdminTextKeys.projectReactivate),
              style: JitanTextStyles.tableCellStrong.copyWith(color: color),
            ),
          );
    final buttons = Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        JitanSecondaryButton(
          label: context.t(CommonTextKeys.cancel),
          onPressed: idle ? () => Navigator.of(context).pop(_saved) : null,
        ),
        JitanPrimaryButton(
          label: context.t(_editing ? AdminTextKeys.projectSave : AdminTextKeys.projectCreate),
          busy: _busy,
          onPressed: _canSave && _changed && idle ? _save : null,
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
}

/// Figma "Deactivate?" (`1562:605`): one plain question; `true` to go ahead.
Future<bool> confirmProjectDeactivate(BuildContext context, ProjectSummary project) async =>
    await showJitanModal<bool>(
      context,
      builder: (dialog) => JitanModal(
        width: 440,
        title: dialog.t(AdminTextKeys.projectDeactivateTitle, args: {'project': project.fullName}),
        subtitle: dialog.t(AdminTextKeys.projectDeactivateText),
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 10,
            children: [
              JitanSecondaryButton(label: dialog.t(CommonTextKeys.cancel), onPressed: () => Navigator.of(dialog).pop(false)),
              JitanPrimaryButton(
                label: dialog.t(AdminTextKeys.projectDeactivate),
                color: JitanColors.errorStrong,
                onPressed: () => Navigator.of(dialog).pop(true),
              ),
            ],
          ),
        ],
      ),
    ) ??
    false;

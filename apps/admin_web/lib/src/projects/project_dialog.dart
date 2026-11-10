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

/// Figma `HR / Projects D44 — Add project` for a client site (`1512:114`: the
/// SAP number and name, then the address beside the map with its pin and
/// area) and for our workshop (`1512:305`: which workshop, no map). A project
/// keeps its kind once added; Deactivate or Reactivate sits on the left.
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
  static const _narrowWidth = 440.0;
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
  bool _changed = false;
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
      id == null ? await widget.api.create(request) : await widget.api.update(id, request);
      if (mounted) Navigator.of(context).pop(true);
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

  /// Deactivate or Reactivate: saved at once, the window stays open.
  Future<void> _toggleActive() async {
    final details = _details!;
    setState(() => _busy = true);
    try {
      final id = details.summary.id;
      final saved = details.summary.isActive ? await widget.api.deactivate(id) : await widget.api.reactivate(id);
      if (!mounted) return;
      setState(() {
        _details = saved;
        _changed = true;
        _busy = false;
      });
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
  Widget build(BuildContext context) {
    final showMap = _clientSite && !_loading;
    return Dialog(
      backgroundColor: JitanColors.surface,
      surfaceTintColor: JitanColors.surface,
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final site = _site;
          if (!showMap || site == null) {
            return SizedBox(
              width: _narrowWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fields(context),
                    Padding(padding: const EdgeInsets.fromLTRB(28, 8, 28, 24), child: _actions(context)),
                  ],
                ),
              ),
            );
          }
          final map = LocationMapPanel(form: site, maps: widget.maps, busy: _busy);
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
            Semantics(
              header: true,
              child: Text(
                context.t(_editing ? AdminTextKeys.projectEditTitle : AdminTextKeys.projectAddTitle),
                style: JitanTextStyles.modalTitle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.t(_clientSite ? AdminTextKeys.projectClientText : AdminTextKeys.projectWorkshopText),
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
            const SizedBox(height: 24),
            if (_loading)
              JitanLoadingState(label: context.t(AdminTextKeys.projectsLoading))
            else ...[
              _KindSwitch(
                clientSite: _clientSite,
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
    final quiet = details == null
        ? null
        : TextButton(
            style: TextButton.styleFrom(foregroundColor: JitanColors.inkMuted, padding: EdgeInsets.zero),
            onPressed: idle ? _toggleActive : null,
            child: Text(context.t(details.summary.isActive ? AdminTextKeys.projectDeactivate : AdminTextKeys.projectReactivate)),
          );
    final buttons = Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        JitanSecondaryButton(
          label: context.t(CommonTextKeys.cancel),
          onPressed: idle ? () => Navigator.of(context).pop(_changed) : null,
        ),
        JitanPrimaryButton(
          label: context.t(_editing ? AdminTextKeys.projectSave : AdminTextKeys.projectCreate),
          busy: _busy,
          onPressed: _canSave && idle ? _save : null,
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

/// Client site or Our workshop (Figma `1512:114`); fixed once added.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.clientSite, required this.onChanged});

  final bool clientSite;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(12)),
    child: Row(
      spacing: 3,
      children: [
        for (final (client, key) in [(true, AdminTextKeys.projectKindClient), (false, AdminTextKeys.projectKindWorkshop)])
          Expanded(
            child: Semantics(
              button: true,
              selected: client == clientSite,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: onChanged == null ? null : () => onChanged!(client),
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: client == clientSite ? JitanColors.surface : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    context.t(key),
                    style: client == clientSite
                        ? JitanTextStyles.tableCellStrong
                        : JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

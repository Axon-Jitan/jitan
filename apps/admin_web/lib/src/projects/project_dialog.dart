import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'project_date_field.dart';
import 'project_failure_note.dart';

/// Adds a project, or changes [project] (its company stays). Returns what the
/// server saved.
Future<ProjectDetails?> showProjectDialog(
  BuildContext context, {
  required ProjectsApi api,
  required CompaniesApi companiesApi,
  required LocationsApi locationsApi,
  ProjectDetails? project,
}) => showJitanModal<ProjectDetails>(
  context,
  barrierDismissible: false,
  builder: (_) => _ProjectDialog(api: api, companiesApi: companiesApi, locationsApi: locationsApi, project: project),
);

/// Figma `HR / Projects — Add project` (`647:1292`, Internal `1481:22`) and
/// `Edit project` (`647:1592`). The client address shows only for a client
/// project, and comes from Locations so Jitan can recognise arrival there.
class _ProjectDialog extends StatefulWidget {
  const _ProjectDialog({required this.api, required this.companiesApi, required this.locationsApi, this.project});

  final ProjectsApi api;
  final CompaniesApi companiesApi;
  final LocationsApi locationsApi;
  final ProjectDetails? project;

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  late final _name = TextEditingController(text: widget.project?.summary.name);
  late final _reference = TextEditingController(text: widget.project?.summary.reference);
  late final _description = TextEditingController(text: widget.project?.description);
  late int? _companyId = widget.project?.summary.companyId;
  late int? _typeId = widget.project?.summary.type.id;
  late int? _statusId = widget.project?.summary.status.id;
  late int? _addressId = widget.project?.addressId;
  late DateTime? _start = widget.project?.startDate;
  late DateTime? _end = widget.project?.endDate;

  ProjectOptions? _options;
  List<CompanySummary> _companies = const [];
  List<Location> _locations = const [];
  ApiClientException? _failure;
  bool _busy = false;
  final _errors = <String, String>{};

  static const _company = 'company';

  bool get _editing => widget.project != null;
  bool get _needsAddress => _options?.addressTypeIds.contains(_typeId) ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _reference.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final options = await widget.api.options();
      final companies = await widget.companiesApi.listCompanies();
      final locations = await widget.locationsApi.list();
      if (!mounted) return;
      setState(() {
        _options = options;
        _companies = [
          for (final company in companies)
            if (company.isActive) company,
        ];
        _locations = [
          for (final location in locations)
            if (location.isActive) location,
        ];
        _statusId ??= options.statuses.firstOrNull?.id;
      });
    } on ApiClientException catch (e) {
      if (mounted) setState(() => _failure = e);
    }
  }

  /// Fills what the form can check itself; the server checks everything.
  bool _check() {
    _errors.clear();
    if (_name.text.trim().isEmpty) _errors[ProjectRequest.fieldName] = AdminTextKeys.projectErrorName;
    if (_companyId == null) _errors[_company] = AdminTextKeys.projectErrorCompany;
    if (_typeId == null) _errors[ProjectRequest.fieldType] = AdminTextKeys.projectErrorType;
    if (_start == null) _errors[ProjectRequest.fieldStartDate] = AdminTextKeys.projectErrorStart;
    if (_needsAddress && _addressId == null) _errors[ProjectRequest.fieldAddress] = AdminTextKeys.projectErrorAddress;
    return _errors.isEmpty;
  }

  Future<void> _save() async {
    final valid = _check();
    setState(() {});
    if (!valid) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final request = ProjectRequest(
      name: _name.text,
      typeId: _typeId!,
      statusId: _statusId!,
      startDate: TimeRecordDay.dateText(_start!),
      endDate: _end == null ? null : TimeRecordDay.dateText(_end!),
      reference: _reference.text,
      description: _description.text,
      addressId: _needsAddress ? _addressId : null,
    );
    try {
      final current = widget.project;
      final saved = current == null
          ? await widget.api.create(_companyId!, request)
          : await widget.api.update(_companyId!, current.summary.id, request);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        final error = e.error;
        final field = error?.field;
        if (error?.code == ApiErrorCode.validationFailed && field == ProjectRequest.fieldEndDate) {
          _errors[field!] = AdminTextKeys.projectErrorEnd;
        } else {
          _failure = e;
        }
      });
    }
  }

  String? _error(String field) {
    final key = _errors[field];
    return key == null ? null : context.t(key);
  }

  Widget _pair(Widget first, Widget? second) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint - 80
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [first, ?second],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 24,
            children: [Expanded(child: first), Expanded(child: second ?? const SizedBox.shrink())],
          ),
  );

  Widget _form(ProjectOptions options) {
    List<JitanSelectOption<int>> choices(List<ProjectChoice> rows) => [
      for (final row in rows) JitanSelectOption(value: row.id, label: row.name),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        _pair(
          JitanTextField(
            label: context.t(AdminTextKeys.projectName),
            controller: _name,
            maxLength: ProjectRequest.maxNameLength,
            errorText: _error(ProjectRequest.fieldName),
          ),
          JitanSelectField<int>(
            label: context.t(AdminTextKeys.projectCompany),
            value: _companyId,
            errorText: _error(_company),
            hintText: context.t(AdminTextKeys.projectChoose),
            options: [for (final c in _companies) JitanSelectOption(value: c.id, label: c.name)],
            onChanged: _editing ? null : (id) => setState(() => _companyId = id),
          ),
        ),
        _pair(
          JitanSelectField<int>(
            label: context.t(AdminTextKeys.projectType),
            value: _typeId,
            errorText: _error(ProjectRequest.fieldType),
            hintText: context.t(AdminTextKeys.projectChoose),
            options: choices(options.types),
            onChanged: (id) => setState(() => _typeId = id),
          ),
          _needsAddress
              ? JitanSelectField<int>(
                  label: context.t(AdminTextKeys.projectAddress),
                  value: _addressId,
                  errorText: _error(ProjectRequest.fieldAddress),
                  hintText: context.t(AdminTextKeys.projectAddressHint),
                  options: [for (final l in _locations) JitanSelectOption(value: l.id, label: l.name)],
                  onChanged: (id) => setState(() => _addressId = id),
                )
              : null,
        ),
        _pair(
          JitanTextField(
            label: context.t(AdminTextKeys.projectReference),
            controller: _reference,
            hintText: context.t(AdminTextKeys.projectReferenceHint),
            maxLength: ProjectRequest.maxReferenceLength,
          ),
          JitanSelectField<int>(
            label: context.t(AdminTextKeys.projectStatus),
            value: _statusId,
            options: choices(options.statuses),
            onChanged: (id) => setState(() => _statusId = id),
          ),
        ),
        _pair(
          ProjectDateField(
            label: context.t(AdminTextKeys.projectStart),
            hint: context.t(AdminTextKeys.projectStartHint),
            value: _start,
            errorText: _error(ProjectRequest.fieldStartDate),
            onChanged: (date) => setState(() => _start = date),
          ),
          ProjectDateField(
            label: context.t(AdminTextKeys.projectEnd),
            hint: context.t(AdminTextKeys.projectOptional),
            value: _end,
            errorText: _error(ProjectRequest.fieldEndDate),
            onChanged: (date) => setState(() => _end = date),
          ),
        ),
        JitanTextField(
          label: context.t(AdminTextKeys.projectDescription),
          controller: _description,
          hintText: context.t(AdminTextKeys.projectDescriptionHint),
          maxLength: ProjectRequest.maxDescriptionLength,
          maxLines: 2,
        ),
        if (_failure case final failure?) ProjectFailureNote(failure),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return JitanModal(
      width: 680,
      title: context.t(_editing ? AdminTextKeys.projectEditTitle : AdminTextKeys.projectAddTitle),
      subtitle: context.t(_editing ? AdminTextKeys.projectEditText : AdminTextKeys.projectAddText),
      onClose: () => Navigator.of(context).pop(),
      body: options != null
          ? _form(options)
          : _failure != null
          ? ProjectFailureNote(_failure!)
          : JitanLoadingState(label: context.t(AdminTextKeys.projectsLoading)),
      actions: [
        JitanSecondaryButton(label: context.t(AdminTextKeys.periodCancel), onPressed: () => Navigator.of(context).pop()),
        JitanPrimaryButton(
          label: context.t(_editing ? AdminTextKeys.projectSave : AdminTextKeys.projectCreate),
          onPressed: options == null || _busy ? null : _save,
        ),
      ],
    );
  }
}

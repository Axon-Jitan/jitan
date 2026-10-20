import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'add_employee_controller.dart';

/// Opens the Add employee modal for [companyId]. Completes with the created
/// employee once the server confirmed it, or `null` when dismissed.
Future<EmployeeSummary?> showAddEmployeeDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required GroupsApi groupsApi,
  required int companyId,
}) => showJitanModal<EmployeeSummary>(
      context,
  builder: (_) => AddEmployeeDialog(employeesApi: employeesApi, groupsApi: groupsApi, companyId: companyId),
);

/// Figma `Admin / Employees — Add employee modal` (`153:266`).
///
/// Differences from Figma, on purpose: **Location** (ERD GAP-11) and **Work
/// policy** (PRODUCT-CLARIFY-EMPLOYEE-POLICY) are left out, and the subtitle
/// does not mention the onboarding QR, which arrives with EMP-08.
class AddEmployeeDialog extends StatefulWidget {
  const AddEmployeeDialog({super.key, required this.employeesApi, required this.groupsApi, required this.companyId});

  final EmployeesApi employeesApi;
  final GroupsApi groupsApi;
  final int companyId;

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  late final AddEmployeeController _controller = AddEmployeeController(
    employeesApi: widget.employeesApi,
    groupsApi: widget.groupsApi,
    companyId: widget.companyId,
  )..loadGroups();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _code = TextEditingController();
  final _phone = TextEditingController();
  int? _groupId;

  @override
  void dispose() {
    _controller.dispose();
    for (final field in [_firstName, _lastName, _code, _phone]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final created = await _controller.submit((
      firstName: _firstName.text,
      lastName: _lastName.text,
      code: _code.text,
      groupId: _groupId,
      phone: _phone.text,
    ));
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final errors = _controller.fieldErrors;
      String? errorFor(String field) => errors[field] == null ? null : context.t(errors[field]!);
      final busy = _controller.submitting;

      return JitanModal(
        title: context.t(AdminTextKeys.employeeAddTitle),
        subtitle: context.t(AdminTextKeys.employeeAddSubtitle),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldRows(
              children: [
                JitanTextField(
                  label: context.t(AdminTextKeys.employeeFieldFirstName),
                  controller: _firstName,
                  enabled: !busy,
                  autofocus: true,
                  maxLength: CreateEmployeeRequest.maxFirstNameLength,
                  errorText: errorFor(CreateEmployeeRequest.fieldFirstName),
                ),
                JitanTextField(
                  label: context.t(AdminTextKeys.employeeFieldLastName),
                  controller: _lastName,
                  enabled: !busy,
                  maxLength: CreateEmployeeRequest.maxLastNameLength,
                  errorText: errorFor(CreateEmployeeRequest.fieldLastName),
                ),
                JitanTextField(
                  label: context.t(AdminTextKeys.employeeFieldCode),
                  controller: _code,
                  enabled: !busy,
                  maxLength: CreateEmployeeRequest.maxCodeLength,
                  errorText: errorFor(CreateEmployeeRequest.fieldCode),
                ),
                _typeField(context, busy: busy, errorText: errorFor(CreateEmployeeRequest.fieldGroupId)),
                JitanTextField(
                  label: context.t(AdminTextKeys.employeeFieldPhone),
                  controller: _phone,
                  enabled: !busy,
                  hintText: context.t(AdminTextKeys.employeeFieldPhoneHint),
                  keyboardType: TextInputType.phone,
                  maxLength: CreateEmployeeRequest.maxPhoneLength,
                  errorText: errorFor(CreateEmployeeRequest.fieldPhone),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
            if (_controller.formFailure case final failure?) ...[
              const SizedBox(height: 20),
              _formError(context, failure),
            ],
          ],
        ),
        actions: [
          JitanPrimaryButton(label: context.t(AdminTextKeys.employeeAddSubmit), busy: busy, onPressed: _submit),
        ],
      );
    },
  );

  Widget _typeField(BuildContext context, {required bool busy, required String? errorText}) {
    final label = context.t(AdminTextKeys.employeeFieldType);
    return switch (_controller.groups) {
      GroupOptionsLoading() => JitanSelectField<int?>(label: label, options: const [], value: null, onChanged: null),
      GroupOptionsFailed() => JitanFieldLabel(
        label: label,
        child: Text(context.t(AdminTextKeys.employeeFieldTypeLoadFailed), style: JitanTextStyles.stateMessage),
      ),
      GroupOptionsLoaded(:final groups) => JitanSelectField<int?>(
        label: label,
        value: _groupId,
        errorText: errorText,
        options: [
          JitanSelectOption(value: null, label: context.t(AdminTextKeys.employeeFieldTypeNone)),
          for (final group in groups) JitanSelectOption(value: group.id, label: group.name),
        ],
        onChanged: busy ? null : (id) => setState(() => _groupId = id),
      ),
    };
  }

  Widget _formError(BuildContext context, ApiClientException failure) {
    if (failure.error?.code == ApiErrorCode.badRequest) {
      return JitanInlineError(
        title: context.t(CommonTextKeys.errorUnexpectedTitle),
        message: context.t(AdminTextKeys.employeeFieldErrorTooLong),
      );
    }
    final keys = failureTextKeysFor(failure);
    return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
  }
}

/// Lays the fields out two per row (Figma), one per row when narrow.
class _FieldRows extends StatelessWidget {
  const _FieldRows({required this.children});

  final List<Widget> children;

  static const _twoColumnWidth = JitanDimensions.fieldWidth * 2 + JitanDimensions.fieldColumnGap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= _twoColumnWidth ? 2 : 1;
      final width = columns == 2 ? JitanDimensions.fieldWidth : constraints.maxWidth;
      return Wrap(
        spacing: JitanDimensions.fieldColumnGap,
        runSpacing: JitanDimensions.fieldRowGap,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

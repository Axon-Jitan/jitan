import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_form_fields.dart';
import '../schedules/schedule_summary_text.dart';
import 'add_employee_controller.dart';
import 'add_employee_progress.dart';
import 'phone_number_input_formatter.dart';
import 'temporary_qr/temporary_qr_controller.dart';
import 'temporary_qr/temporary_qr_panel.dart';

/// What Add employee ended with: the employee, and whether they already
/// finished setting up with the QR of step 3.
typedef AddedEmployee = ({EmployeeSummary employee, bool setUp});

/// Opens Add employee. HR chooses the employee's companies in step 2.
/// Completes with the created employee once HR is done, `null` when closed
/// before the employee was created.
Future<AddedEmployee?> showAddEmployeeDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required GroupsApi groupsApi,
  required CompaniesApi companiesApi,
  required SchedulesApi schedulesApi,
}) => showJitanModal<AddedEmployee>(
  context,
  // A click beside the dialog must not throw away what HR entered.
  barrierDismissible: false,
  builder: (_) => AddEmployeeDialog(
    employeesApi: employeesApi,
    groupsApi: groupsApi,
    companiesApi: companiesApi,
    schedulesApi: schedulesApi,
  ),
);

/// Figma Add employee: Details (`1536:2`, a missing field `1536:195`), Work
/// (`1536:389`) and Set up (`1536:569`), with a slim progress bar.
///
/// Decided with the product owner: no "Employee type" in step 1 (it is the
/// group, chosen in step 2); no default company until IT adds it (GAP-03);
/// the hours come from the groups chosen. The employee is created when HR
/// leaves step 2 ("Add employee"), so step 3 has no Back; its QR closes the
/// dialog by itself once the employee is set up.
class AddEmployeeDialog extends StatefulWidget {
  const AddEmployeeDialog({
    super.key,
    required this.employeesApi,
    required this.groupsApi,
    required this.companiesApi,
    required this.schedulesApi,
  });

  final EmployeesApi employeesApi;
  final GroupsApi groupsApi;
  final CompaniesApi companiesApi;
  final SchedulesApi schedulesApi;

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  late final _controller = AddEmployeeController(
    employeesApi: widget.employeesApi,
    groupsApi: widget.groupsApi,
    companiesApi: widget.companiesApi,
    schedulesApi: widget.schedulesApi,
  );

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _code = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  /// Step 3's QR, made once the employee exists.
  TemporaryQrController? _qr;

  @override
  void initState() {
    super.initState();
    // A message goes as soon as HR types in its field.
    for (final (field, name) in [
      (_firstName, CreateEmployeeRequest.fieldFirstName),
      (_lastName, CreateEmployeeRequest.fieldLastName),
      (_code, CreateEmployeeRequest.fieldCode),
      (_phone, CreateEmployeeRequest.fieldPhone),
      (_email, CreateEmployeeRequest.fieldEmail),
    ]) {
      field.addListener(() => _controller.clearError(name));
    }
  }

  @override
  void dispose() {
    _qr
      ?..removeListener(_closeWhenSetUp)
      ..dispose();
    _controller.dispose();
    for (final field in [_firstName, _lastName, _code, _phone, _email]) {
      field.dispose();
    }
    super.dispose();
  }

  void _continue() => _controller.next((
    firstName: _firstName.text,
    lastName: _lastName.text,
    code: _code.text,
    phone: _phone.text,
    email: _email.text,
  ));

  TemporaryQrController _qrFor(EmployeeSummary created) => _qr ??= TemporaryQrController(
    api: widget.employeesApi,
    companyId: _controller.createdIn!,
    userId: created.id,
    purpose: TemporaryQrPurpose.onboarding,
  )..addListener(_closeWhenSetUp);

  void _closeWhenSetUp() {
    final created = _controller.created;
    if (_qr?.used == true && created != null && mounted) Navigator.of(context).pop((employee: created, setUp: true));
  }

  void _done() => Navigator.of(context).pop((employee: _controller.created!, setUp: false));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      final created = c.created;
      final failure = c.formFailure;
      if (c.step == AddEmployeeStep.activation && created != null) return _setUp(context, created);
      final details = c.step == AddEmployeeStep.information;
      return JitanModal(
        width: 560,
        title: context.t(AdminTextKeys.employeeAddTitle),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AddEmployeeProgress(
              step: details ? 1 : 2,
              label: context.t(details ? AdminTextKeys.employeeAddStepDetails : AdminTextKeys.employeeAddStepWork),
            ),
            const SizedBox(height: 22),
            ...details ? _details(context) : _work(context),
            if (failure != null) ...[
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
        leadingActions: [
          TextButton(
            onPressed: c.submitting ? null : (details ? () => Navigator.of(context).pop() : c.back),
            style: TextButton.styleFrom(foregroundColor: JitanColors.ink, padding: const EdgeInsets.symmetric(horizontal: 4)),
            child: Text(
              context.t(details ? CommonTextKeys.cancel : CommonTextKeys.back),
              style: JitanTextStyles.tableCellStrong,
            ),
          ),
        ],
        actions: [
          if (details)
            JitanPrimaryButton(label: context.t(AdminTextKeys.employeeAddContinue), onPressed: _continue)
          else
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.employeeAddAction),
              busy: c.submitting,
              onPressed: c.options is AssignmentOptionsLoaded ? c.create : null,
            ),
        ],
      );
    },
  );

  /// Step 3 (`1536:569`): added; the onboarding QR, as in the QR pop-up.
  Widget _setUp(BuildContext context, EmployeeSummary created) {
    final qr = _qrFor(created);
    final fullName = [created.firstName, created.lastName].whereType<String>().join(' ');
    return ListenableBuilder(
      listenable: qr,
      builder: (context, _) => JitanModal(
        width: 560,
        title: context.t(AdminTextKeys.employeeAddAdded, args: {'name': fullName.isEmpty ? created.code : fullName}),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AddEmployeeProgress(step: 3, label: context.t(AdminTextKeys.employeeAddStepSetUp)),
            const SizedBox(height: 22),
            TemporaryQrPanel(
              controller: qr,
              fullName: fullName,
              callName: created.firstName ?? (fullName.isEmpty ? created.code : fullName),
              size: 208,
            ),
          ],
        ),
        leadingActions: TemporaryQrPanel.leadingActions(context, qr),
        actions: TemporaryQrPanel.actions(context, qr, onDone: _done),
      ),
    );
  }

  String? _error(String field) {
    final key = _controller.fieldErrors[field];
    if (key == null) return null;
    // A missing field says which one (Figma `1536:195`).
    return context.t(switch ((key, field)) {
      (AdminTextKeys.employeeFieldErrorRequired, CreateEmployeeRequest.fieldFirstName) => AdminTextKeys.employeeFieldMissingFirstName,
      (AdminTextKeys.employeeFieldErrorRequired, CreateEmployeeRequest.fieldLastName) => AdminTextKeys.employeeFieldMissingLastName,
      (AdminTextKeys.employeeFieldErrorRequired, CreateEmployeeRequest.fieldCode) => AdminTextKeys.employeeFieldMissingCode,
      (AdminTextKeys.employeeFieldErrorRequired, CreateEmployeeRequest.fieldCompanyIds) => AdminTextKeys.employeeFieldMissingCompany,
      _ => key,
    });
  }

  /// Step 1 (`1536:2`): names and code, then phone and email (optional).
  List<Widget> _details(BuildContext context) {
    final optional = context.t(AdminTextKeys.employeeFieldOptional);
    return [
      ScheduleFieldColumns(
        children: [
          JitanTextField(
            label: context.t(AdminTextKeys.employeeFieldFirstName),
            controller: _firstName,
            autofocus: true,
            errorText: _error(CreateEmployeeRequest.fieldFirstName),
          ),
          JitanTextField(
            label: context.t(AdminTextKeys.employeeFieldLastName),
            controller: _lastName,
            errorText: _error(CreateEmployeeRequest.fieldLastName),
          ),
          JitanTextField(
            label: context.t(AdminTextKeys.employeeFieldCode),
            hintText: context.t(AdminTextKeys.employeeFieldCodeHint),
            controller: _code,
            errorText: _error(CreateEmployeeRequest.fieldCode),
          ),
          const SizedBox.shrink(),
          JitanTextField(
            label: context.t(AdminTextKeys.employeeFieldPhone),
            note: optional,
            hintText: context.t(AdminTextKeys.employeeFieldPhoneHint),
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: const [PhoneNumberInputFormatter()],
            errorText: _error(CreateEmployeeRequest.fieldPhone),
          ),
          JitanTextField(
            label: context.t(AdminTextKeys.employeeFieldEmail),
            note: optional,
            hintText: context.t(AdminTextKeys.employeeFieldEmailHint),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _continue(),
            errorText: _error(CreateEmployeeRequest.fieldEmail),
          ),
        ],
      ),
    ];
  }

  /// Step 2 (`1536:389`): companies and groups; the hours follow the groups.
  List<Widget> _work(BuildContext context) {
    final c = _controller;
    return switch (c.options) {
      AssignmentOptionsLoading() => [GroupStateText(context.t(AdminTextKeys.employeeAddLoading))],
      AssignmentOptionsFailed() => [GroupStateText(context.t(AdminTextKeys.groupsPickerLoadFailed), onRetry: c.loadOptions)],
      AssignmentOptionsLoaded(:final companies, :final groups) => [
        JitanMultiSelectField<int>(
          label: context.t(AdminTextKeys.employeeFieldCompanies),
          hintText: context.t(AdminTextKeys.employeeFieldCompaniesHint),
          options: [for (final company in companies) JitanSelectOption(value: company.id, label: company.name)],
          values: c.companyIds,
          errorText: _error(CreateEmployeeRequest.fieldCompanyIds),
          onChanged: c.submitting ? null : c.setCompanies,
        ),
        const SizedBox(height: 16),
        JitanMultiSelectField<int>(
          label: context.t(AdminTextKeys.employeeFieldGroups),
          hintText: context.t(AdminTextKeys.employeeFieldGroupsHint),
          options: [for (final group in groups) JitanSelectOption(value: group.id, label: group.name)],
          values: c.groupIds,
          errorText: _error(CreateEmployeeRequest.fieldGroupIds),
          onChanged: c.submitting ? null : c.setGroups,
        ),
        ..._hours(context),
      ],
    };
  }

  /// Nothing before a group is chosen; then the hours they give, plainly
  /// when there is one, a choice when several groups have hours.
  List<Widget> _hours(BuildContext context) {
    final c = _controller;
    if (c.groupIds.isEmpty) return const [];
    final choices = c.scheduleChoices;
    String hoursOf(GroupSchedule s) => context.t(
      AdminTextKeys.employeeAddHoursFrom,
      args: {'hours': workHoursDaysSummary(TranslationScope.of(context), s.variants.single), 'group': s.group.name},
    );
    if (choices.length > 1) {
      return [
        const SizedBox(height: 16),
        JitanSelectField<int>(
          label: context.t(AdminTextKeys.employeeAddHoursChoose),
          hintText: context.t(AdminTextKeys.employeeFieldScheduleChoose),
          value: c.scheduleGroupId,
          options: [for (final s in choices) JitanSelectOption(value: s.group.id, label: hoursOf(s))],
          errorText: _error(CreateEmployeeRequest.fieldScheduleGroupId),
          onChanged: c.submitting ? null : c.setScheduleGroup,
        ),
      ];
    }
    return [
      const SizedBox(height: 16),
      DecoratedBox(
        decoration: BoxDecoration(color: JitanColors.tableHeader, borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(context.t(AdminTextKeys.employeeAddHours), style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  choices.isEmpty ? context.t(AdminTextKeys.employeeAddHoursNone) : hoursOf(choices.single),
                  textAlign: TextAlign.end,
                  style: choices.isEmpty
                      ? JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)
                      : JitanTextStyles.tableCellStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

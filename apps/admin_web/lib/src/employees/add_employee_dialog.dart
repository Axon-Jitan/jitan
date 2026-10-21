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
import 'add_employee_activation.dart';
import 'add_employee_controller.dart';
import 'add_employee_stepper.dart';

/// Opens Add employee for [companyId]. Completes with the created employee
/// once HR finished the setup, `null` when closed before the employee was
/// created.
Future<EmployeeSummary?> showAddEmployeeDialog(
  BuildContext context, {
  required EmployeesApi employeesApi,
  required GroupsApi groupsApi,
  required CompaniesApi companiesApi,
  required SchedulesApi schedulesApi,
  required int companyId,
}) => showJitanModal<EmployeeSummary>(
  context,
  // A click beside the dialog must not throw away what HR entered.
  barrierDismissible: false,
  builder: (_) => AddEmployeeDialog(
    employeesApi: employeesApi,
    groupsApi: groupsApi,
    companiesApi: companiesApi,
    schedulesApi: schedulesApi,
    companyId: companyId,
  ),
);

/// Figma `HR / Employees — Add employee`: Step 1 information (`153:970`),
/// Step 2 assignments (`985:2`, lists `993:292`, `993:596`, `992:2`) and
/// Step 3 onboarding (`1233:2`), as the prototype links them.
///
/// Decided with the product owner on 2026-10-21: "Employee type" is left
/// out of step 1 (it is the employee's group, chosen in step 2; Figma to be
/// updated); "Default company" is left out until IT adds it to the database
/// (ERD_GAPS GAP-03); "Work schedule" offers the hours of the groups chosen
/// for the employee. The employee is created when HR leaves step 2, so step
/// 3 has no Back.
class AddEmployeeDialog extends StatefulWidget {
  const AddEmployeeDialog({
    super.key,
    required this.employeesApi,
    required this.groupsApi,
    required this.companiesApi,
    required this.schedulesApi,
    required this.companyId,
  });

  final EmployeesApi employeesApi;
  final GroupsApi groupsApi;
  final CompaniesApi companiesApi;
  final SchedulesApi schedulesApi;
  final int companyId;

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  late final _controller = AddEmployeeController(
    employeesApi: widget.employeesApi,
    groupsApi: widget.groupsApi,
    companiesApi: widget.companiesApi,
    schedulesApi: widget.schedulesApi,
    companyId: widget.companyId,
  );

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _code = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      final busy = c.submitting;
      final created = c.created;
      final failure = c.formFailure;
      return JitanModal(
        width: 835,
        title: context.t(AdminTextKeys.employeeAddTitle),
        subtitle: switch (c.step) {
          AddEmployeeStep.information => context.t(AdminTextKeys.employeeAddSubtitle),
          AddEmployeeStep.assignments => context.t(AdminTextKeys.employeeAddSubtitleAssignments),
          // No subtitle in Figma, but the same space, so the dialog keeps its size.
          AddEmployeeStep.activation => '',
        },
        // Once created, closing is "Finish setup".
        onClose: busy ? null : () => Navigator.of(context).pop(created),
        footerNote: context.t(AdminTextKeys.employeeAddStepOf, args: {'n': c.step.index + 1, 'total': 3}),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AddEmployeeStepper(
              current: c.step.index,
              labels: [
                context.t(AdminTextKeys.employeeAddStepInformation),
                context.t(AdminTextKeys.employeeAddStepAssignments),
                context.t(AdminTextKeys.employeeAddStepActivation),
              ],
            ),
            const SizedBox(height: 24),
            // The same size on every step, as in Figma (all three frames are
            // one size): a long step scrolls inside it.
            SizedBox(
              height: _stepHeight(MediaQuery.sizeOf(context)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...switch (c.step) {
                      AddEmployeeStep.information => _information(context),
                      AddEmployeeStep.assignments => _assignments(context),
                      AddEmployeeStep.activation => [
                        AddEmployeeActivation(
                          employee: created!,
                          companyName: _companyName,
                          qr: c.qr,
                          failure: c.qrFailure,
                          onRetry: c.requestQr,
                        ),
                      ],
                    },
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
              ),
            ),
          ],
        ),
        actions: switch (c.step) {
          AddEmployeeStep.information => [
            JitanPrimaryButton(label: context.t(AdminTextKeys.employeeAddContinue), onPressed: _continue),
          ],
          AddEmployeeStep.assignments => [
            JitanSecondaryButton(label: context.t(CommonTextKeys.back), onPressed: busy ? null : c.back),
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.employeeAddContinue),
              busy: busy,
              onPressed: c.options is AssignmentOptionsLoaded ? c.create : null,
            ),
          ],
          AddEmployeeStep.activation => [
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.employeeAddFinish),
              onPressed: () => Navigator.of(context).pop(created),
            ),
          ],
        },
      );
    },
  );

  /// 430 px on a wide screen; on a phone the fields stack, so it uses the
  /// screen's extra height (up to 560 px); on a short window it shrinks.
  static double _stepHeight(Size screen) =>
      (screen.height - 350).clamp(280.0, screen.width < JitanDimensions.phoneBreakpoint ? 560.0 : 430.0);

  String get _companyName => switch (_controller.options) {
    AssignmentOptionsLoaded(:final companies) =>
      companies.where((company) => company.id == widget.companyId).firstOrNull?.name ?? '',
    _ => '',
  };

  String? _error(String field) => _controller.fieldErrors[field] == null ? null : context.t(_controller.fieldErrors[field]!);

  /// Step 1 (`153:970`): personal information and contact details.
  List<Widget> _information(BuildContext context) => [
    Text(context.t(AdminTextKeys.employeeAddSectionPersonal), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
    const SizedBox(height: 20),
    ScheduleFieldColumns(
      children: [
        JitanTextField(
          label: context.t(AdminTextKeys.employeeFieldFirstName),
          hintText: context.t(AdminTextKeys.employeeFieldFirstNameHint),
          controller: _firstName,
          autofocus: true,
          errorText: _error(CreateEmployeeRequest.fieldFirstName),
        ),
        JitanTextField(
          label: context.t(AdminTextKeys.employeeFieldLastName),
          hintText: context.t(AdminTextKeys.employeeFieldLastNameHint),
          controller: _lastName,
          errorText: _error(CreateEmployeeRequest.fieldLastName),
        ),
        JitanTextField(
          label: context.t(AdminTextKeys.employeeFieldCode),
          hintText: context.t(AdminTextKeys.employeeFieldCodeHint),
          controller: _code,
          errorText: _error(CreateEmployeeRequest.fieldCode),
        ),
      ],
    ),
    const SizedBox(height: 28),
    Text(context.t(AdminTextKeys.employeeAddSectionContact), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
    const SizedBox(height: 20),
    ScheduleFieldColumns(
      children: [
        JitanTextField(
          label: context.t(AdminTextKeys.employeeFieldPhone),
          hintText: context.t(AdminTextKeys.employeeFieldPhoneHint),
          controller: _phone,
          keyboardType: TextInputType.phone,
          errorText: _error(CreateEmployeeRequest.fieldPhone),
        ),
        JitanTextField(
          label: context.t(AdminTextKeys.employeeFieldEmail),
          hintText: context.t(AdminTextKeys.employeeFieldPhoneHint),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continue(),
          errorText: _error(CreateEmployeeRequest.fieldEmail),
        ),
      ],
    ),
  ];

  /// Step 2 (`985:2`): companies, employee groups and the work schedule.
  List<Widget> _assignments(BuildContext context) {
    final c = _controller;
    final heading = Text(context.t(AdminTextKeys.employeeAddSectionAssignments), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18));
    return switch (c.options) {
      AssignmentOptionsLoading() => [heading, const SizedBox(height: 20), GroupStateText(context.t(AdminTextKeys.employeeAddLoading))],
      AssignmentOptionsFailed() => [
        heading,
        const SizedBox(height: 20),
        GroupStateText(context.t(AdminTextKeys.groupsPickerLoadFailed), onRetry: c.loadOptions),
      ],
      AssignmentOptionsLoaded(:final companies, :final groups) => [
        heading,
        const SizedBox(height: 20),
        ScheduleFieldColumns(
          children: [
            JitanMultiSelectField<int>(
              label: context.t(AdminTextKeys.employeeFieldCompanies),
              hintText: context.t(AdminTextKeys.employeeFieldCompaniesHint),
              options: [for (final company in companies) JitanSelectOption(value: company.id, label: company.name)],
              values: c.companyIds,
              locked: {widget.companyId},
              errorText: _error(CreateEmployeeRequest.fieldCompanyIds),
              onChanged: c.submitting ? null : c.setCompanies,
            ),
            JitanMultiSelectField<int>(
              label: context.t(AdminTextKeys.employeeFieldGroups),
              hintText: context.t(AdminTextKeys.employeeFieldGroupsHint),
              options: [for (final group in groups) JitanSelectOption(value: group.id, label: group.name)],
              values: c.groupIds,
              errorText: _error(CreateEmployeeRequest.fieldGroupIds),
              onChanged: c.submitting ? null : c.setGroups,
            ),
            const SizedBox.shrink(),
            JitanSelectField<int>(
              label: context.t(AdminTextKeys.employeeFieldSchedule),
              value: c.scheduleGroupId,
              options: [
                for (final schedule in c.scheduleChoices)
                  JitanSelectOption(
                    value: schedule.group.id,
                    label: context.t(
                      AdminTextKeys.employeeFieldScheduleOption,
                      args: {'group': schedule.group.name, 'hours': workHoursDaysSummary(TranslationScope.of(context), schedule.variants.single)},
                    ),
                  ),
              ],
              errorText: _error(CreateEmployeeRequest.fieldScheduleGroupId),
              onChanged: c.submitting || c.scheduleChoices.length < 2 ? null : c.setScheduleGroup,
            ),
          ],
        ),
      ],
    };
  }
}

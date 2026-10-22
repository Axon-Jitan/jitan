import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_form_controller.dart';
import '../schedules/schedule_form_fields.dart';
import '../schedules/schedule_summary_text.dart';
import 'create_group_controller.dart';
import 'employee_picker.dart';
import 'group_hours_choice.dart';
import 'group_state_text.dart';

/// Opens Create group; completes with the new group once the server created
/// it with its employees and work hours, `null` when closed before that.
Future<GroupOverview?> showCreateGroupDialog(
  BuildContext context, {
  required GroupManagementApi groupsApi,
  required GroupMembersApi membersApi,
  required SchedulesApi schedulesApi,
}) => showJitanModal<GroupOverview>(
  context,
  // A click beside the dialog must not throw away what HR entered.
  barrierDismissible: false,
  builder: (_) => CreateGroupDialog(groupsApi: groupsApi, membersApi: membersApi, schedulesApi: schedulesApi),
);

/// Figma `HR / Employee groups — Create group`: Step 1 Details (1340:160,
/// name error 1340:836), Step 2 Employees (1352:2, list open 1354:7) and
/// Step 3 Work hours & breaks (1377:28 empty, 1352:175 filled, 1377:290 per
/// day, 1377:569 invalid finish). "Create group" saves all three together;
/// employees and hours may be left empty (product owner, 2026-10-21).
class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key, required this.groupsApi, required this.membersApi, required this.schedulesApi});

  final GroupManagementApi groupsApi;
  final GroupMembersApi membersApi;
  final SchedulesApi schedulesApi;

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  late final _controller = CreateGroupController(groupsApi: widget.groupsApi, schedulesApi: widget.schedulesApi);
  final _name = TextEditingController();
  final _break = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.addListener(() => _controller.setName(_name.text));
    _break.addListener(() => _controller.setBreak(_break.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _break.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final created = await _controller.submit();
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      final busy = c.submitting;
      final failure = c.failure;
      return JitanModal(
        width: 690,
        title: context.t(AdminTextKeys.groupsCreateTitle),
        subtitle: context.t(AdminTextKeys.groupsCreateSubtitle),
        onClose: busy ? null : () => Navigator.of(context).pop(),
        bandFooter: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScheduleStepper(
              current: c.step.index,
              labels: [
                for (final (index, key) in [
                  AdminTextKeys.groupsStepDetails,
                  AdminTextKeys.groupsStepEmployees,
                  AdminTextKeys.groupsStepHours,
                ].indexed)
                  context.t(AdminTextKeys.scheduleStepLabel, args: {'n': index + 1, 'label': context.t(key)}),
              ],
            ),
            const SizedBox(height: 28),
            // The same size on every step and while the employee list is
            // open, as in the schedule wizard: a long step scrolls inside.
            SizedBox(
              height: _stepHeight(MediaQuery.sizeOf(context)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...switch (c.step) {
                      CreateGroupStep.details => _details(context),
                      CreateGroupStep.employees => _employees(context),
                      CreateGroupStep.hours => _hours(context),
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
        leadingActions: [
          JitanSecondaryButton(
            label: context.t(c.step == CreateGroupStep.details ? CommonTextKeys.cancel : CommonTextKeys.back),
            onPressed: busy ? null : () => c.step == CreateGroupStep.details ? Navigator.of(context).pop() : c.back(),
          ),
        ],
        actions: [
          if (c.step == CreateGroupStep.hours || c.skipsHours)
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.groupsCreateSubmit),
              busy: busy,
              onPressed: c.canSubmit ? _submit : null,
            )
          else
            JitanPrimaryButton(label: context.t(CommonTextKeys.continueAction), onPressed: c.canContinue ? c.next : null),
        ],
      );
    },
  );

  /// Step 1: the name (1340:160).
  List<Widget> _details(BuildContext context) {
    final error = _controller.nameError;
    return [
      Text(context.t(AdminTextKeys.groupsStepDetails), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
      const SizedBox(height: 24),
      JitanFieldLabel(
        label: context.t(AdminTextKeys.groupsFieldName),
        child: TextField(
          controller: _name,
          autofocus: true,
          maxLength: GroupNameRequest.maxNameLength,
          style: JitanTextStyles.inputText,
          onSubmitted: (_) => _controller.next(),
          decoration: jitanFieldDecoration(
            hintText: context.t(AdminTextKeys.groupsFieldNameHint),
            errorText: error == null ? null : context.t(error),
          ).copyWith(counterText: ''),
        ),
      ),
      const SizedBox(height: 10),
      Text(context.t(AdminTextKeys.groupsFieldNameHelp), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
    ];
  }

  /// Step 2: employees from every company (1352:2, 1354:7). Continue needs
  /// someone in no other group: the work hours are kept on them.
  List<Widget> _employees(BuildContext context) {
    final c = _controller;
    final name = c.name.trim();
    return [
      JitanFieldLabel(
        label: context.t(AdminTextKeys.groupsEmployeesField),
        child: EmployeePicker(
          dropdown: true,
          enabled: !c.submitting,
          hintKey: AdminTextKeys.groupsEmployeesHint,
          noOtherGroupsKey: AdminTextKeys.groupsPickerNoOtherGroups,
          load: (search) => widget.membersApi.candidates(null, search: search),
          selected: c.selected,
          onChanged: c.setSelected,
        ),
      ),
      // The chosen employees, each with whose hours they will work (1405:473).
      for (final (index, employee) in c.selected.values.indexed)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            color: index.isOdd ? JitanColors.tableStripe : JitanColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${employee.displayName} · ${employee.code}', style: JitanTextStyles.tableCellStrong, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      employee.groups.isEmpty
                          ? context.t(AdminTextKeys.groupsPickerNoOtherGroups)
                          : context.t(AdminTextKeys.groupsPickerAlsoIn, args: {'groups': employee.groups.join(', ')}),
                      style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    GroupHoursChoice(
                      employee: employee,
                      groupName: name,
                      follows: c.follows(employee),
                      onChanged: c.submitting ? null : (follows) => c.setFollows(employee.id, follows),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.t(AdminTextKeys.groupsEmployeesRemove),
                onPressed: c.submitting ? null : () => c.deselect(employee.id),
                icon: const Icon(Icons.close, size: 16, color: JitanColors.inkMuted),
              ),
            ],
          ),
        ),
      if (c.selected.isNotEmpty) ...[
        const SizedBox(height: 14),
        if (c.skipsHours)
          Text(
            context.t(AdminTextKeys.groupsEmployeesAllKeep, args: {'group': name}),
            style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
          )
        else
          Text(
            context.t(AdminTextKeys.groupsEmployeesWillWork, args: {'n': c.willWorkCount, 'total': c.selected.length, 'group': name}),
            style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
          ),
      ],
    ];
  }

  /// Step 3: working days, their hours and the break (1377:28, 1352:175,
  /// 1377:290, 1377:569).
  List<Widget> _hours(BuildContext context) => switch (_controller.options) {
    ScheduleOptionsLoading() => [GroupStateText(context.t(AdminTextKeys.scheduleFormOptionsLoading))],
    ScheduleOptionsFailed() => [
      GroupStateText(context.t(AdminTextKeys.groupsPickerLoadFailed), onRetry: _controller.loadOptions),
    ],
    ScheduleOptionsLoaded(:final options) => _hoursForm(context, options),
  };

  List<Widget> _hoursForm(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    final t = TranslationScope.of(context);
    final weekdays = [for (final day in options.days) if (day.weekday <= DateTime.friday) day.id];
    final hoursError = c.hoursErrorKey;
    final breakError = c.breakErrorKey;
    Widget error(String key, [Map<String, Object> args = const {}]) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(context.t(key, args: args), style: JitanTextStyles.fieldError),
    );
    return [
      Row(
        children: [
          Expanded(child: Text(context.t(AdminTextKeys.scheduleFormDays), style: JitanTextStyles.stateTitle)),
          TextButton(
            onPressed: busy ? null : () => c.selectDays(weekdays),
            child: Text(
              context.t(AdminTextKeys.scheduleFormWeekdays),
              style: JitanTextStyles.inputText.copyWith(color: JitanColors.vermilion),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final day in options.days)
            ScheduleDayToggle(
              label: dayShortName(t, day.weekday),
              selected: c.dayIds.contains(day.id),
              onPressed: busy ? null : () => c.toggleDay(day.id),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: ScheduleCheckRow(
          label: context.t(AdminTextKeys.scheduleFormSameHours),
          value: c.sameHours,
          onChanged: busy ? null : c.setSameHours,
        ),
      ),
      const SizedBox(height: 16),
      if (c.sameHours)
        ScheduleFieldColumns(
          children: [
            ScheduleTimeField(
              label: context.t(AdminTextKeys.scheduleFormStart),
              hint: context.t(AdminTextKeys.groupsHoursStartHint),
              value: c.start,
              onChanged: busy ? null : c.setStart,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScheduleTimeField(
                  label: context.t(AdminTextKeys.scheduleFormFinish),
                  hint: context.t(AdminTextKeys.groupsHoursFinishHint),
                  value: c.finish,
                  onChanged: busy ? null : c.setFinish,
                ),
                if (hoursError != null) error(hoursError),
              ],
            ),
          ],
        )
      else ...[
        for (final day in options.days)
          if (c.dayIds.contains(day.id))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 92, child: Text(dayShortName(t, day.weekday), style: JitanTextStyles.inputText)),
                  Expanded(
                    child: ScheduleTimeField(
                      hint: context.t(AdminTextKeys.groupsHoursStartHint),
                      value: c.hoursOf(day.id).start,
                      onChanged: busy ? null : (time) => c.setDayStart(day.id, time),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ScheduleTimeField(
                      hint: context.t(AdminTextKeys.groupsHoursFinishHint),
                      value: c.hoursOf(day.id).finish,
                      onChanged: busy ? null : (time) => c.setDayFinish(day.id, time),
                    ),
                  ),
                ],
              ),
            ),
        if (hoursError != null) error(hoursError),
      ],
      const SizedBox(height: 16),
      ScheduleFieldColumns(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(context.t(AdminTextKeys.groupsHoursBreak), style: JitanTextStyles.fieldLabel),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _break,
                enabled: !busy,
                keyboardType: TextInputType.number,
                maxLength: 3,
                style: JitanTextStyles.inputText,
                decoration: jitanFieldDecoration(
                  hintText: context.t(AdminTextKeys.groupsHoursBreakHint),
                ).copyWith(counterText: ''),
              ),
              if (breakError != null)
                error(breakError, {'choices': c.breakLengths.join(', '), 'minutes': c.breakLengths.join(', ')}),
            ],
          ),
        ],
      ),
      if (c.hoursFailureKey case final key?) error(key),
    ];
  }

  /// 430 px on a wide screen. On a phone the fields stack, so the step uses
  /// the screen's extra height (up to 520 px) and the break field stays in
  /// view; on a short window it shrinks so the dialog still fits.
  static double _stepHeight(Size screen) =>
      (screen.height - 350).clamp(280.0, screen.width < JitanDimensions.phoneBreakpoint ? 520.0 : 430.0);
}

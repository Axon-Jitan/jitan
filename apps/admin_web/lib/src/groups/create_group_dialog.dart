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

/// Figma `HR / Groups V2`: Group (`1555:2`, the name and the employees),
/// Hours (`1556:556`, with "Set hours later"), then Rules and Review as in
/// Schedules (`1552:12`, `1552:201`). "Create group" saves everything
/// together, so HR sets up a whole group in one pass (product owner,
/// 2026-10-22); employees and hours may be left for later.
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
  final _arrival = TextEditingController(text: '0');
  final _leaving = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _name.addListener(() => _controller.setName(_name.text));
    _arrival.addListener(() => _controller.setArrivalTolerance(_arrival.text));
    _leaving.addListener(() => _controller.setLeavingTolerance(_leaving.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _arrival.dispose();
    _leaving.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final created = await _controller.submit();
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  static const _stepNames = [
    AdminTextKeys.scheduleStepGroup,
    AdminTextKeys.scheduleStepHours,
    AdminTextKeys.scheduleStepRules,
    AdminTextKeys.scheduleStepReview,
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      final busy = c.submitting;
      final failure = c.failure;
      final name = c.name.trim();
      return JitanModal(
        width: 520,
        title: context.t(AdminTextKeys.groupsCreateTitle),
        // On every step, so the pop-up keeps one size: the name as typed.
        subtitle: name.isEmpty ? context.t(AdminTextKeys.groupsNewGroup) : name,
        onClose: busy ? null : () => Navigator.of(context).pop(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScheduleStepper(current: c.step.index, labels: [for (final key in _stepNames) context.t(key)]),
            const SizedBox(height: 22),
            // One height on every step, as in the schedule wizard, so the
            // pop-up never jumps; a long step scrolls inside it.
            SizedBox(
              height: wizardStepHeight(MediaQuery.sizeOf(context)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...switch (c.step) {
                      CreateGroupStep.group => _group(context),
                      CreateGroupStep.hours => _hours(context),
                      CreateGroupStep.attendance => _rules(context),
                      CreateGroupStep.review => _review(context),
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
            label: context.t(c.step == CreateGroupStep.group ? CommonTextKeys.cancel : CommonTextKeys.back),
            onPressed: busy ? null : () => c.step == CreateGroupStep.group ? Navigator.of(context).pop() : c.back(),
          ),
        ],
        actions: [
          if (c.step == CreateGroupStep.review || (c.step == CreateGroupStep.group && c.skipsHours))
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.groupsCreateSubmit),
              busy: busy,
              onPressed: c.canSubmit ? _submit : null,
            )
          else if (c.step == CreateGroupStep.hours)
            // "Set hours later" sits next to Continue (1556:556).
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : c.setHoursLater,
                  child: Text(context.t(AdminTextKeys.groupsHoursLater), style: JitanTextStyles.buttonLabel.copyWith(color: JitanColors.ink)),
                ),
                JitanPrimaryButton(label: context.t(CommonTextKeys.continueAction), onPressed: c.canContinue ? c.next : null),
              ],
            )
          else
            JitanPrimaryButton(label: context.t(CommonTextKeys.continueAction), onPressed: c.canContinue ? c.next : null),
        ],
      );
    },
  );

  Widget _label(String text, {String? trailing}) => Row(
    children: [
      Expanded(child: Text(text, style: JitanTextStyles.fieldLabel.copyWith(color: JitanColors.ink))),
      if (trailing != null) Text(trailing, style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
    ],
  );

  Widget _error(String text) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(text, style: JitanTextStyles.fieldError),
  );

  /// Step 1 (1555:2): the name and the employees from every company. A
  /// ticked employee in other groups chooses whose hours they work.
  List<Widget> _group(BuildContext context) {
    final c = _controller;
    final error = c.nameError;
    final name = c.name.trim();
    return [
      _label(context.t(AdminTextKeys.groupsFieldNameLabel)),
      const SizedBox(height: 8),
      TextField(
        controller: _name,
        autofocus: true,
        enabled: !c.submitting,
        maxLength: GroupNameRequest.maxNameLength,
        style: JitanTextStyles.inputText,
        onSubmitted: (_) => _controller.next(),
        decoration: jitanFieldDecoration(
          hintText: context.t(AdminTextKeys.groupsFieldNameHint),
          errorText: error == null ? null : context.t(error),
        ).copyWith(counterText: ''),
      ),
      const SizedBox(height: 20),
      _label(
        context.t(AdminTextKeys.groupsEmployeesField),
        trailing: c.selected.isEmpty ? null : context.tPlural(AdminTextKeys.groupsEmployeesChosen, c.selected.length),
      ),
      const SizedBox(height: 8),
      EmployeePicker(
        enabled: !c.submitting,
        load: (search) => widget.membersApi.candidates(null, search: search),
        selected: c.selected,
        onChanged: c.setSelected,
        trailing: (employee) => employee.groups.isEmpty
            ? null
            : GroupHoursChoice(
                employee: employee,
                groupName: name.isEmpty ? context.t(AdminTextKeys.groupsThisGroup) : name,
                follows: c.follows(employee),
                onChanged: c.submitting ? null : (follows) => c.setFollows(employee.id, follows),
              ),
      ),
      if (c.skipsHours) ...[
        const SizedBox(height: 12),
        Text(
          context.t(AdminTextKeys.groupsEmployeesAllKeep, args: {'group': name}),
          style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
        ),
      ],
    ];
  }

  /// Step 2 (1556:556): the days, the hours and the break, as in Schedules.
  List<Widget> _hours(BuildContext context) => switch (_controller.options) {
    ScheduleOptionsLoading() => [GroupStateText(context.t(AdminTextKeys.scheduleFormOptionsLoading))],
    ScheduleOptionsFailed() => [GroupStateText(context.t(AdminTextKeys.groupsPickerLoadFailed), onRetry: _controller.loadOptions)],
    ScheduleOptionsLoaded(:final options) => _hoursForm(context, options),
  };

  List<Widget> _hoursForm(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    final t = TranslationScope.of(context);
    final hint = context.t(AdminTextKeys.scheduleFormTimeHint);
    final start = context.t(AdminTextKeys.scheduleFormStart), finish = context.t(AdminTextKeys.scheduleFormFinish);
    final hoursError = c.hoursErrorKey;
    final breakError = c.breakErrorKey;
    Widget range(String day, ({String? start, String? finish}) hours, ValueChanged<String?> onFrom, ValueChanged<String?> onTo) {
      final from = _minutesOf(hours.start), to = _minutesOf(hours.finish);
      final bad = hoursError != null && from != null && to != null && to <= from;
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          ScheduleTimeField(chip: true, hint: hint, value: hours.start, onChanged: busy ? null : onFrom, semanticLabel: '$day $start'),
          Text('–', style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
          ScheduleTimeField(chip: true, hint: hint, value: hours.finish, onChanged: busy ? null : onTo, semanticLabel: '$day $finish', failed: bad),
        ],
      );
    }

    final hoursLabel = context.t(AdminTextKeys.scheduleRowHours);
    return [
      JitanSettingsCard(
        rows: [
          JitanSettingsRow(
            label: context.t(AdminTextKeys.scheduleRowWorkDays),
            info: context.t(AdminTextKeys.scheduleInfoDays),
            value: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final day in options.days)
                  ScheduleDayDot(
                    letter: dayLetter(t, day.weekday),
                    name: dayShortName(t, day.weekday),
                    selected: c.dayIds.contains(day.id),
                    onPressed: busy ? null : () => c.toggleDay(day.id),
                  ),
              ],
            ),
          ),
          if (c.sameHours)
            JitanSettingsRow(
              label: hoursLabel,
              info: context.t(AdminTextKeys.scheduleInfoHours),
              value: range(hoursLabel, (start: c.start, finish: c.finish), c.setStart, c.setFinish),
            )
          else
            for (final day in options.days)
              if (c.dayIds.contains(day.id))
                JitanSettingsRow(
                  label: dayLongName(t, day.weekday),
                  value: range(
                    dayLongName(t, day.weekday),
                    c.hoursOf(day.id),
                    (time) => c.setDayStart(day.id, time),
                    (time) => c.setDayFinish(day.id, time),
                  ),
                ),
          JitanSettingsRow(
            label: context.t(AdminTextKeys.scheduleRowBreak),
            info: context.t(AdminTextKeys.scheduleInfoBreak),
            value: JitanInlineSelect<int>(
              menuWidth: 160,
              value: c.breakLength,
              hintText: context.t(CommonTextKeys.valueUnavailable),
              options: [
                for (final minutes in options.breakLengthMinutes)
                  JitanSelectOption(value: minutes, label: context.t(AdminTextKeys.scheduleFormLengthOption, args: {'minutes': minutes})),
              ],
              onChanged: busy ? null : c.setBreakLength,
            ),
          ),
        ],
      ),
      if (hoursError != null) _error(context.t(hoursError)),
      if (breakError != null) _error(context.t(breakError)),
      if (c.hoursFailureKey case final key?) _error(context.t(key)),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: busy ? null : () => c.setSameHours(!c.sameHours),
          style: TextButton.styleFrom(
            foregroundColor: JitanColors.inkMuted,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            minimumSize: Size.zero,
          ),
          child: Text(
            context.t(c.sameHours ? AdminTextKeys.scheduleFormPerDay : AdminTextKeys.scheduleFormSameEveryDay),
            style: JitanTextStyles.tableCell.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: JitanColors.inkMuted),
          ),
        ),
      ),
    ];
  }

  /// Step 3: tolerance and rounding, as in Schedules (1552:12).
  List<Widget> _rules(BuildContext context) {
    final c = _controller;
    final busy = c.submitting;
    final unit = context.t(AdminTextKeys.scheduleFormMinutesUnit);
    final intervals = switch (c.options) {
      ScheduleOptionsLoaded(:final options) => options.roundingIntervalMinutes,
      _ => const <int>[],
    };
    Widget minutes(String labelKey, String infoKey, TextEditingController controller, String field) {
      final label = context.t(labelKey);
      return JitanSettingsRow(
        label: label,
        info: context.t(infoKey),
        value: ScheduleMinutesChip(
          controller: controller,
          unit: unit,
          enabled: !busy,
          semanticLabel: label,
          failed: c.toleranceErrors.containsKey(field),
        ),
      );
    }

    Widget rounding(String labelKey, String infoKey, ScheduleRounding? value, ValueChanged<ScheduleRounding?> onChanged) =>
        JitanSettingsRow(
          label: context.t(labelKey),
          info: context.t(infoKey),
          value: ScheduleRoundingSelect(value: value, intervals: intervals, onChanged: busy ? null : onChanged),
        );

    final toleranceError = c.toleranceErrors.values.firstOrNull;
    return [
      JitanSettingsCard(
        rows: [
          minutes(AdminTextKeys.scheduleRowArrival, AdminTextKeys.scheduleInfoArrival, _arrival, 'arrival'),
          minutes(AdminTextKeys.scheduleRowLeaving, AdminTextKeys.scheduleInfoLeaving, _leaving, 'leaving'),
          rounding(AdminTextKeys.scheduleRowStartRounding, AdminTextKeys.scheduleInfoStartRounding, c.startRounding, c.setStartRounding),
          rounding(AdminTextKeys.scheduleRowFinishRounding, AdminTextKeys.scheduleInfoFinishRounding, c.finishRounding, c.setFinishRounding),
        ],
      ),
      if (toleranceError != null) _error(context.t(toleranceError, args: {'max': c.maxToleranceMinutes})),
    ];
  }

  /// Step 4: everything that will be saved, in the card of Schedules.
  List<Widget> _review(BuildContext context) {
    final c = _controller;
    final t = TranslationScope.of(context);
    final days = switch (c.options) {
      ScheduleOptionsLoaded(:final options) => {for (final d in options.days) d.id: d},
      _ => const <int, ScheduleDay>{},
    };
    final employees = [
      for (final e in c.selected.values)
        e.groups.isEmpty || c.follows(e) ? e.displayName : context.t(AdminTextKeys.groupsReviewKeeps, args: {'name': e.displayName}),
    ];
    final variant = ScheduleVariant(
      employeeCount: 0,
      breaks: const [],
      workDays: [
        for (final (id, start, finish) in c.enteredHours)
          if (days[id] case final day?)
            WorkDaySchedule(
              day: day,
              start: WorkBoundary(time: start, toleranceMinutes: 0),
              finish: WorkBoundary(time: finish, toleranceMinutes: 0),
            ),
      ],
    );
    Widget row(String labelKey, String value) => JitanSettingsRow(label: context.t(labelKey), value: JitanSettingsRow.text(value));
    return [
      JitanSettingsCard(
        rows: [
          row(AdminTextKeys.groupsReviewEmployees, employees.isEmpty ? context.t(AdminTextKeys.groupsReviewNoEmployees) : employees.join(', ')),
          if (c.withHours) ...[
            row(AdminTextKeys.scheduleRowWorkDays, workDaysText(t, variant)),
            row(AdminTextKeys.scheduleRowHours, workHoursText(t, variant)),
            row(AdminTextKeys.scheduleRowBreak, context.t(AdminTextKeys.scheduleFormLengthOption, args: {'minutes': c.breakLength ?? 0})),
            row(
              AdminTextKeys.scheduleRowTolerance,
              toleranceText(t, int.tryParse(c.arrivalTolerance.trim()) ?? 0, int.tryParse(c.leavingTolerance.trim()) ?? 0),
            ),
            row(AdminTextKeys.scheduleRowRounding, roundingShortText(t, c.startRounding, c.finishRounding)),
          ] else
            row(AdminTextKeys.scheduleRowHours, context.t(AdminTextKeys.groupsReviewHoursLater)),
        ],
      ),
      const SizedBox(height: 14),
      Text(context.t(AdminTextKeys.groupsReviewNote), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
      if (c.hoursFailureKey case final key?) _error(context.t(key)),
    ];
  }

  /// Minutes since midnight of a typed time, `null` when it is not one.
  static int? _minutesOf(String? time) => switch (tidyTime(time ?? '')) {
    null => null,
    final t => int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3)),
  };
}

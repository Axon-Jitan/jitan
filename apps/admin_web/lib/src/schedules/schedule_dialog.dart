import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'schedule_form_controller.dart';
import 'schedule_form_fields.dart';
import 'schedule_summary_text.dart';

/// Opens Create schedule, or Edit schedule for [group]. Completes with the
/// group's schedule once the server saved it, `null` when closed.
Future<GroupSchedule?> showScheduleDialog(
  BuildContext context, {
  required SchedulesApi api,
  required List<GroupSchedule> groups,
  ScheduleOptions? options,
  GroupSchedule? group,
}) => showJitanModal<GroupSchedule>(
  context,
  builder: (_) => ScheduleDialog(api: api, groups: groups, options: options, group: group),
);

/// The Create / Edit schedule wizard: Group → Working hours & break →
/// Attendance rules → Review, then one save of the whole schedule. Every
/// field has an ⓘ explaining it with an example.
///
/// Built from the Figma wizard (1365:…, `Daily hours` 1367:2, the blocked,
/// warning and conflict states 1317:742, 933, 1124) with the flow agreed on
/// 2026-10-20: work hours and break together in one pass. Also agreed: the
/// "Mon–Fri" shortcut and dark chosen days.
class ScheduleDialog extends StatefulWidget {
  const ScheduleDialog({super.key, required this.api, required this.groups, this.options, this.group});

  final SchedulesApi api;
  final List<GroupSchedule> groups;

  /// The form's choices when already loaded; otherwise the dialog loads them.
  final ScheduleOptions? options;
  final GroupSchedule? group;

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  late final ScheduleFormController _controller = ScheduleFormController(
    widget.api,
    groups: widget.groups,
    group: widget.group,
    options: widget.options,
  );

  late final _arrival = TextEditingController(text: _controller.arrivalTolerance);
  late final _leaving = TextEditingController(text: _controller.leavingTolerance);

  @override
  void initState() {
    super.initState();
    if (widget.options == null) _controller.loadOptions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _arrival.dispose();
    _leaving.dispose();
    super.dispose();
  }

  void _editExisting() {
    _controller.editExisting();
    _arrival.text = _controller.arrivalTolerance;
    _leaving.text = _controller.leavingTolerance;
  }

  void _syncTolerance() => _controller
    ..arrivalTolerance = _arrival.text
    ..leavingTolerance = _leaving.text;

  Future<void> _save() async {
    _syncTolerance();
    final saved = await _controller.submit();
    if (saved != null && mounted) Navigator.of(context).pop(saved);
  }

  static const _stepNames = {
    ScheduleStep.group: AdminTextKeys.scheduleStepGroup,
    ScheduleStep.hours: AdminTextKeys.scheduleStepHoursBreak,
    ScheduleStep.attendance: AdminTextKeys.scheduleStepAttendance,
    ScheduleStep.review: AdminTextKeys.scheduleStepReview,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      return JitanModal(
        width: 680,
        title: context.t(c.editing ? AdminTextKeys.scheduleFormEditTitle : AdminTextKeys.scheduleFormCreateTitle),
        subtitle: context.t(AdminTextKeys.scheduleFormSubtitle),
        onClose: c.submitting ? null : () => Navigator.of(context).pop(),
        bandFooter: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScheduleStepper(
              current: c.step.index,
              labels: [
                for (final step in ScheduleStep.values)
                  context.t(AdminTextKeys.scheduleStepLabel, args: {'n': step.index + 1, 'label': context.t(_stepNames[step]!)}),
              ],
            ),
            const SizedBox(height: 28),
            // The same size on every step; a long step (7 days of hours)
            // scrolls inside it.
            SizedBox(
              height: _stepHeight,
              child: switch (c.options) {
                ScheduleOptionsLoading() => JitanLoadingState(label: context.t(AdminTextKeys.scheduleFormOptionsLoading)),
                ScheduleOptionsFailed(:final failure) => _optionsError(context, failure),
                ScheduleOptionsLoaded(:final options) => SingleChildScrollView(child: _step(context, options)),
              },
            ),
          ],
        ),
        leadingActions: [
          JitanSecondaryButton(
            label: context.t(c.step == ScheduleStep.group ? CommonTextKeys.cancel : CommonTextKeys.back),
            onPressed: c.submitting
                ? null
                : c.step == ScheduleStep.group
                ? () => Navigator.of(context).pop()
                : () {
                    _syncTolerance();
                    c.back();
                  },
          ),
        ],
        actions: [
          if (c.onLastStep)
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.scheduleFormSave),
              busy: c.submitting,
              onPressed: c.canSave ? _save : null,
            )
          else
            JitanPrimaryButton(
              label: context.t(CommonTextKeys.continueAction),
              onPressed: c.canContinue
                  ? () {
                      _syncTolerance();
                      c.next();
                    }
                  : null,
            ),
        ],
      );
    },
  );

  Widget _step(BuildContext context, ScheduleOptions options) => Column(
    key: ValueKey(_controller.step),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ...switch (_controller.step) {
        ScheduleStep.group => _group(context),
        ScheduleStep.hours => _hours(context, options),
        ScheduleStep.attendance => _attendance(context, options),
        ScheduleStep.review => _review(context, options),
      },
      _fieldError(context, ScheduleFormController.fieldForm),
      if (_controller.failure case final failure?) ...[
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final keys = failureTextKeysFor(failure);
            return JitanInlineError(title: context.t(keys.title), message: context.t(keys.message));
          },
        ),
      ],
    ],
  );

  /// Step 1: which group.
  List<Widget> _group(BuildContext context) {
    final c = _controller;
    final group = c.group;
    return [
      if (group != null && c.blocked)
        ScheduleFormBanner.error(context.t(AdminTextKeys.scheduleFormBlocked, args: {'group': group.group.name}))
      else if (group != null && c.conflict)
        ScheduleFormBanner.note(
          context.t(AdminTextKeys.scheduleFormConflict, args: {'group': group.group.name}),
          action: context.t(AdminTextKeys.scheduleFormConflictAction),
          onAction: _editExisting,
        )
      else if (group != null && c.employeesDiffer)
        ScheduleFormBanner.warning(context.t(AdminTextKeys.scheduleFormDiffer, args: {'group': group.group.name})),
      JitanSelectField<int>(
        label: context.t(AdminTextKeys.scheduleFormGroup),
        info: context.t(AdminTextKeys.scheduleInfoGroup),
        hintText: context.t(AdminTextKeys.scheduleFormGroupHint),
        value: c.groupId,
        options: [for (final g in c.groups) JitanSelectOption(value: g.group.id, label: g.group.name)],
        onChanged: c.submitting || c.editing ? null : c.selectGroup,
      ),
      const SizedBox(height: 14),
      Text(context.t(AdminTextKeys.scheduleFormAppliesToGroup), style: _note),
    ];
  }

  /// Step 2: working days, their hours and the break (Figma 1365:222,
  /// `Daily hours` 1367:2).
  List<Widget> _hours(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    final t = TranslationScope.of(context);
    final hint = context.t(AdminTextKeys.scheduleFormTimeHint);
    return [
      ..._days(context, options),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: ScheduleCheckRow(
          label: context.t(AdminTextKeys.scheduleFormSameHours),
          value: c.sameHours,
          onChanged: busy ? null : c.setSameHours,
        ),
      ),
      const SizedBox(height: 20),
      if (c.sameHours)
        ScheduleFieldColumns(
          children: [
            ScheduleTimeField(
              label: context.t(AdminTextKeys.scheduleFormStart),
              info: context.t(AdminTextKeys.scheduleInfoStart),
              hint: hint,
              value: c.start,
              onChanged: busy ? null : c.setStart,
            ),
            ScheduleTimeField(
              label: context.t(AdminTextKeys.scheduleFormFinish),
              info: context.t(AdminTextKeys.scheduleInfoFinish),
              hint: hint,
              value: c.finish,
              onChanged: busy ? null : c.setFinish,
            ),
          ],
        )
      else ...[
        ScheduleHoursTable(
          dayLabel: context.t(AdminTextKeys.scheduleFormDay),
          startLabel: context.t(AdminTextKeys.scheduleFormStart),
          finishLabel: context.t(AdminTextKeys.scheduleFormFinish),
          startInfo: context.t(AdminTextKeys.scheduleInfoStart),
          finishInfo: context.t(AdminTextKeys.scheduleInfoFinish),
          timeHint: hint,
          lines: [
            for (final day in options.days)
              if (c.dayIds.contains(day.id))
                (
                  day: dayShortName(t, day.weekday),
                  start: c.hoursOf(day.id).start,
                  finish: c.hoursOf(day.id).finish,
                  onStart: busy ? null : (String? time) => c.setDayStart(day.id, time),
                  onFinish: busy ? null : (String? time) => c.setDayFinish(day.id, time),
                ),
          ],
        ),
        const SizedBox(height: 12),
        Text(context.t(AdminTextKeys.scheduleFormDailyNote), style: _note),
      ],
      _fieldError(context, ScheduleFormController.fieldHours),
      // The break: always part of a schedule; HR only sets its length and
      // the server places it in the middle of each working day (D28).
      const SizedBox(height: 24),
      ScheduleFieldColumns(
        children: [
          JitanSelectField<int>(
            label: context.t(AdminTextKeys.scheduleFormLength),
            info: context.t(AdminTextKeys.scheduleInfoBreak),
            value: c.breakLength,
            options: [
              for (final minutes in options.breakLengthMinutes)
                JitanSelectOption(
                  value: minutes,
                  label: context.t(AdminTextKeys.scheduleFormLengthOption, args: {'minutes': minutes}),
                ),
            ],
            onChanged: busy ? null : c.setBreakLength,
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(context.t(AdminTextKeys.scheduleBreakEveryDayText), style: _note),
      _fieldError(context, ScheduleFormController.fieldBreak),
    ];
  }

  /// Step 3: attendance tolerance and rounding (Figma 1365:457).
  List<Widget> _attendance(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    return [
      ScheduleFieldColumns(
        children: [
          _toleranceField(context, AdminTextKeys.scheduleFormArrivalTolerance, AdminTextKeys.scheduleInfoArrival, _arrival,
              ScheduleFormController.fieldArrival),
          _toleranceField(context, AdminTextKeys.scheduleFormLeavingTolerance, AdminTextKeys.scheduleInfoLeaving, _leaving,
              ScheduleFormController.fieldLeaving),
        ],
      ),
      const SizedBox(height: 20),
      ScheduleFieldColumns(
        children: [
          ScheduleRoundingField(
            label: context.t(AdminTextKeys.scheduleFormStartRounding),
            info: context.t(AdminTextKeys.scheduleInfoStartRounding),
            value: c.startRounding,
            intervals: options.roundingIntervalMinutes,
            onChanged: busy ? null : c.setStartRounding,
          ),
          ScheduleRoundingField(
            label: context.t(AdminTextKeys.scheduleFormFinishRounding),
            info: context.t(AdminTextKeys.scheduleInfoFinishRounding),
            value: c.finishRounding,
            intervals: options.roundingIntervalMinutes,
            onChanged: busy ? null : c.setFinishRounding,
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(context.t(AdminTextKeys.scheduleFormAttendanceNote), style: _note),
    ];
  }

  /// Step 4: everything that will be saved.
  List<Widget> _review(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final t = TranslationScope.of(context);
    final hours = workHoursDaysSummary(
      t,
      ScheduleVariant(
        employeeCount: 0,
        breaks: const [],
        workDays: [
          for (final day in options.days)
            if (c.dayIds.contains(day.id))
              WorkDaySchedule(
                day: day,
                start: WorkBoundary(time: c.effectiveHoursOf(day.id).start ?? '', toleranceMinutes: 0),
                finish: WorkBoundary(time: c.effectiveHoursOf(day.id).finish ?? '', toleranceMinutes: 0),
              ),
        ],
      ),
    );
    final rows = [
      (AdminTextKeys.scheduleReviewGroup, c.group?.group.name ?? ''),
      (AdminTextKeys.scheduleReviewHours, hours),
      (
        AdminTextKeys.scheduleReviewBreak,
        context.t(AdminTextKeys.scheduleReviewBreakValue, args: {'minutes': c.breakLength ?? 0}),
      ),
      (
        AdminTextKeys.scheduleReviewAttendance,
        context.t(AdminTextKeys.scheduleReviewAttendanceValue, args: {'arrival': c.arrivalTolerance, 'leaving': c.leavingTolerance}),
      ),
      (
        AdminTextKeys.scheduleReviewRounding,
        context.t(
          AdminTextKeys.scheduleSummaryRounding,
          args: {'start': roundingText(t, c.startRounding), 'finish': roundingText(t, c.finishRounding)},
        ),
      ),
    ];
    return [
      Text(context.t(AdminTextKeys.scheduleReviewTitle), style: JitanTextStyles.stateTitle),
      const SizedBox(height: 14),
      for (final (index, (label, value)) in rows.indexed)
        DecoratedBox(
          decoration: BoxDecoration(
            color: index.isOdd ? JitanColors.warmWhite : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 140, child: Text(context.t(label), style: JitanTextStyles.fieldLabel)),
                Expanded(child: Text(value, style: JitanTextStyles.inputText)),
              ],
            ),
          ),
        ),
      const SizedBox(height: 14),
      Text(context.t(AdminTextKeys.scheduleReviewNote), style: _note),
    ];
  }

  /// "Working days" with the "Mon–Fri" shortcut and a chip per day.
  List<Widget> _days(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    final weekdays = [for (final day in options.days) if (day.weekday <= DateTime.friday) day.id];
    return [
      Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: JitanLabelText(
                label: context.t(AdminTextKeys.scheduleFormDays),
                info: context.t(AdminTextKeys.scheduleInfoDays),
                style: JitanTextStyles.stateTitle,
              ),
            ),
          ),
          TextButton(
            onPressed: busy ? null : () => c.selectDays(weekdays),
            child: Text(
              context.t(AdminTextKeys.scheduleFormWeekdays),
              style: JitanTextStyles.inputText.copyWith(fontWeight: FontWeight.w600, color: JitanColors.vermilion),
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
              label: dayShortName(TranslationScope.of(context), day.weekday),
              selected: c.dayIds.contains(day.id),
              onPressed: busy ? null : () => c.toggleDay(day.id),
            ),
        ],
      ),
      _fieldError(context, ScheduleFormController.fieldDays),
    ];
  }

  Widget _toleranceField(
    BuildContext context,
    String labelKey,
    String infoKey,
    TextEditingController controller,
    String field,
  ) => ScheduleMinutesField(
        label: context.t(labelKey),
        info: context.t(infoKey),
        controller: controller,
        unit: context.t(AdminTextKeys.scheduleFormMinutesUnit),
        enabled: !_controller.submitting,
        errorText: _errorText(context, field),
      );

  String? _errorText(BuildContext context, String field) => switch (_controller.fieldErrors[field]) {
    null => null,
    (:final key, :final args) => context.t(key, args: args),
  };

  Widget _fieldError(BuildContext context, String field) => switch (_errorText(context, field)) {
    null => const SizedBox.shrink(),
    final text => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: JitanTextStyles.fieldError),
    ),
  };

  Widget _optionsError(BuildContext context, ApiClientException failure) {
    final keys = failureTextKeysFor(failure);
    return JitanErrorState(
      title: context.t(keys.title),
      message: context.t(keys.message),
      retryLabel: context.t(CommonTextKeys.retry),
      onRetry: _controller.loadOptions,
    );
  }

  static final _note = JitanTextStyles.stateMessage.copyWith(fontSize: 13);

  /// Height of every step's content: fits the days, the hours, the break
  /// and a message; a longer hours table scrolls.
  static const _stepHeight = 430.0;
}

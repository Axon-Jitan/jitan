import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/api_failure_text.dart';
import '../l10n/admin_text_keys.dart';
import 'schedule_form_controller.dart';
import 'schedule_form_fields.dart';
import 'schedule_rows.dart';
import 'schedule_summary_text.dart';

/// Opens Create schedule, or Edit schedule for [group]'s [kind]. Completes
/// with the group's schedule once the server saved it, `null` when closed.
Future<GroupSchedule?> showScheduleDialog(
  BuildContext context, {
  required SchedulesApi api,
  required List<GroupSchedule> groups,
  ScheduleOptions? options,
  GroupSchedule? group,
  ScheduleKind? kind,
}) => showJitanModal<GroupSchedule>(
  context,
  builder: (_) => ScheduleDialog(api: api, groups: groups, options: options, group: group, kind: kind),
);

/// The Create / Edit schedule wizard (Figma 1365:2–2488, `Daily hours`
/// 1367:2 and 1367:273):
///
/// - Work hours: 1 Group & type → 2 Working hours → 3 Attendance rules.
/// - Break: 1 Group & type → 2 Break details → 3 Review.
///
/// The blocked, warning and conflict messages (Figma 1317:742, 933, 1124)
/// show on step 1, where the group is chosen. Agreed additions to Figma:
/// the "Mon–Fri" shortcut and dark chosen days (2026-10-20).
class ScheduleDialog extends StatefulWidget {
  const ScheduleDialog({super.key, required this.api, required this.groups, this.options, this.group, this.kind});

  final SchedulesApi api;
  final List<GroupSchedule> groups;

  /// The form's choices when already loaded; otherwise the dialog loads them.
  final ScheduleOptions? options;
  final GroupSchedule? group;
  final ScheduleKind? kind;

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  late final ScheduleFormController _controller = ScheduleFormController(
    widget.api,
    groups: widget.groups,
    group: widget.group,
    kind: widget.kind,
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      final workHours = c.kind == ScheduleKind.workHours;
      final steps = [
        context.t(AdminTextKeys.scheduleStepGroupType),
        context.t(workHours ? AdminTextKeys.scheduleStepWorkingHours : AdminTextKeys.scheduleStepBreakDetails),
        context.t(workHours ? AdminTextKeys.scheduleStepAttendance : AdminTextKeys.scheduleStepReview),
      ];
      return JitanModal(
        width: 640,
        title: context.t(c.editing ? AdminTextKeys.scheduleFormEditTitle : AdminTextKeys.scheduleFormCreateTitle),
        subtitle: context.t(workHours ? AdminTextKeys.scheduleFormWorkHoursSubtitle : AdminTextKeys.scheduleFormBreaksSubtitle),
        onClose: c.submitting ? null : () => Navigator.of(context).pop(),
        bandFooter: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScheduleStepper(
              current: c.step,
              labels: [
                for (final (index, label) in steps.indexed)
                  context.t(AdminTextKeys.scheduleStepLabel, args: {'n': index + 1, 'label': label}),
              ],
            ),
            const SizedBox(height: 28),
            // Each step has its own height: animate between them.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: switch (c.options) {
                ScheduleOptionsLoading() => SizedBox(
                  height: 160,
                  child: JitanLoadingState(label: context.t(AdminTextKeys.scheduleFormOptionsLoading)),
                ),
                ScheduleOptionsFailed(:final failure) => SizedBox(height: 220, child: _optionsError(context, failure)),
                ScheduleOptionsLoaded(:final options) => _step(context, options),
              },
            ),
          ],
        ),
        leadingActions: [
          JitanSecondaryButton(
            label: context.t(c.step == 0 ? CommonTextKeys.cancel : CommonTextKeys.back),
            onPressed: c.submitting
                ? null
                : c.step == 0
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
              onPressed: c.canContinue ? c.next : null,
            ),
        ],
      );
    },
  );

  Widget _step(BuildContext context, ScheduleOptions options) => Column(
    key: ValueKey(_controller.step),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ...switch ((_controller.step, _controller.kind)) {
        (0, _) => _groupAndType(context),
        (1, ScheduleKind.workHours) => _workingHours(context, options),
        (1, ScheduleKind.breaks) => _breakDetails(context, options),
        (_, ScheduleKind.workHours) => _attendanceRules(context, options),
        (_, ScheduleKind.breaks) => _breakReview(context, options),
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

  /// Step 1 (Figma 1365:2): which group, which kind of schedule.
  List<Widget> _groupAndType(BuildContext context) {
    final c = _controller;
    final busy = c.submitting;
    final group = c.group;
    return [
      if (group != null && c.blocked)
        ScheduleFormBanner.error(context.t(AdminTextKeys.scheduleFormBlocked, args: {'group': group.group.name}))
      else if (group != null && c.conflict)
        ScheduleFormBanner.note(
          context.t(
            c.kind == ScheduleKind.workHours
                ? AdminTextKeys.scheduleFormConflictWorkHours
                : AdminTextKeys.scheduleFormConflictBreaks,
            args: {'group': group.group.name},
          ),
          action: context.t(AdminTextKeys.scheduleFormConflictAction),
          onAction: _editExisting,
        )
      else if (group != null && c.employeesDiffer)
        ScheduleFormBanner.warning(context.t(AdminTextKeys.scheduleFormDiffer, args: {'group': group.group.name})),
      ScheduleFieldColumns(
        children: [
          JitanSelectField<int>(
            label: context.t(AdminTextKeys.scheduleFormGroup),
            hintText: context.t(AdminTextKeys.scheduleFormGroupHint),
            value: c.groupId,
            options: [for (final g in c.groups) JitanSelectOption(value: g.group.id, label: g.group.name)],
            onChanged: busy || c.editing ? null : c.selectGroup,
          ),
          JitanSelectField<ScheduleKind>(
            label: context.t(AdminTextKeys.scheduleFormType),
            value: c.kind,
            options: [
              JitanSelectOption(value: ScheduleKind.workHours, label: context.t(AdminTextKeys.scheduleKindWorkHours)),
              JitanSelectOption(value: ScheduleKind.breaks, label: context.t(AdminTextKeys.scheduleKindBreaks)),
            ],
            onChanged: busy || c.editing ? null : (kind) => c.selectKind(kind!),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(context.t(AdminTextKeys.scheduleFormAppliesToGroup), style: _note),
    ];
  }

  /// Step 2 for work hours (Figma 1365:222, `Daily hours` 1367:2).
  List<Widget> _workingHours(BuildContext context, ScheduleOptions options) {
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
              hint: hint,
              value: c.start,
              onChanged: busy ? null : c.setStart,
            ),
            ScheduleTimeField(
              label: context.t(AdminTextKeys.scheduleFormFinish),
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
    ];
  }

  /// Step 3 for work hours (Figma 1365:457).
  List<Widget> _attendanceRules(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    return [
      ScheduleFieldColumns(
        children: [
          _toleranceField(context, AdminTextKeys.scheduleFormArrivalTolerance, _arrival, ScheduleFormController.fieldArrival),
          _toleranceField(context, AdminTextKeys.scheduleFormLeavingTolerance, _leaving, ScheduleFormController.fieldLeaving),
        ],
      ),
      const SizedBox(height: 20),
      ScheduleFieldColumns(
        children: [
          ScheduleRoundingField(
            label: context.t(AdminTextKeys.scheduleFormStartRounding),
            value: c.startRounding,
            intervals: options.roundingIntervalMinutes,
            onChanged: busy ? null : c.setStartRounding,
          ),
          ScheduleRoundingField(
            label: context.t(AdminTextKeys.scheduleFormFinishRounding),
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

  /// Step 2 for a break (Figma 1365:903).
  List<Widget> _breakDetails(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    return [
      ..._days(context, options),
      const SizedBox(height: 20),
      ScheduleFieldColumns(
        children: [
          ScheduleTimeField(
            label: context.t(AdminTextKeys.scheduleFormUsualTime),
            hint: context.t(AdminTextKeys.scheduleFormTimeHint),
            value: c.breakStart,
            onChanged: busy ? null : c.setBreakStart,
          ),
          JitanSelectField<int>(
            label: context.t(AdminTextKeys.scheduleFormLength),
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
      _fieldError(context, ScheduleFormController.fieldBreak),
    ];
  }

  /// Step 3 for a break (Figma 1365:1137): what will be saved.
  List<Widget> _breakReview(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final t = TranslationScope.of(context);
    final days = [for (final day in options.days) if (c.dayIds.contains(day.id)) day];
    return [
      Text(context.t(AdminTextKeys.scheduleReviewBreakTitle), style: JitanTextStyles.stateTitle),
      const SizedBox(height: 14),
      Text(
        context.t(
          AdminTextKeys.scheduleReviewBreakSummary,
          args: {
            'group': c.group?.group.name ?? '',
            'days': dayListText(t, [for (final day in days) day.weekday]),
            'start': c.breakStart ?? '',
            'minutes': c.breakLength ?? 0,
          },
        ),
        style: JitanTextStyles.inputText,
      ),
      const SizedBox(height: 12),
      Text(context.t(AdminTextKeys.scheduleReviewBreakNote), style: _note),
      _fieldError(context, ScheduleFormController.fieldBreak),
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
          Expanded(child: Text(context.t(AdminTextKeys.scheduleFormDays), style: JitanTextStyles.stateTitle)),
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

  Widget _toleranceField(BuildContext context, String labelKey, TextEditingController controller, String field) =>
      ScheduleMinutesField(
        label: context.t(labelKey),
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
}

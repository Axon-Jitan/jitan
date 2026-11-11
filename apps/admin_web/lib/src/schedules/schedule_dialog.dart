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
  int? groupId,
  bool fromGroupPage = false,
}) => showJitanModal<GroupSchedule>(
  context,
  // A click beside the wizard must not throw away what HR entered.
  barrierDismissible: false,
  builder: (_) => ScheduleDialog(api: api, groups: groups, options: options, group: group, groupId: groupId, fromGroupPage: fromGroupPage),
);

/// The Create / Edit schedule wizard (Figma `HR / Schedules V3`: Hours
/// `1551:2`, hours per day `1551:207`, Rules `1552:12`, Review `1552:201`):
/// one calm card per step, then one save of the whole schedule. The
/// explanations are behind the ⓘ of each line.
class ScheduleDialog extends StatefulWidget {
  const ScheduleDialog({
    super.key,
    required this.api,
    required this.groups,
    this.options,
    this.group,
    this.groupId,
    this.fromGroupPage = false,
  });

  final SchedulesApi api;
  final List<GroupSchedule> groups;

  /// The form's choices when already loaded; otherwise the dialog loads them.
  final ScheduleOptions? options;
  final GroupSchedule? group;

  /// A new schedule for this group, already chosen.
  final int? groupId;

  /// Opened on the group's page: the group is fixed.
  final bool fromGroupPage;

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  late final ScheduleFormController _controller = ScheduleFormController(
    widget.api,
    groups: widget.groups,
    group: widget.group,
    groupId: widget.groupId,
    options: widget.options,
    fromGroupPage: widget.fromGroupPage,
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
    ScheduleStep.hours: AdminTextKeys.scheduleStepHours,
    ScheduleStep.attendance: AdminTextKeys.scheduleStepRules,
    ScheduleStep.review: AdminTextKeys.scheduleStepReview,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      return JitanModal(
        width: 520,
        title: context.t(c.editing ? AdminTextKeys.scheduleFormEditTitle : AdminTextKeys.scheduleFormCreateTitle),
        subtitle: c.groupLocked ? c.group?.group.name : null,
        onClose: c.submitting ? null : () => Navigator.of(context).pop(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScheduleStepper(
              current: c.step.index,
              labels: [for (final step in ScheduleStep.values) context.t(_stepNames[step]!)],
            ),
            const SizedBox(height: 22),
            // One height on every step, so the pop-up never jumps; a long
            // step (hours per day) scrolls inside it.
            SizedBox(
              height: wizardStepHeight(MediaQuery.sizeOf(context)),
              child: SingleChildScrollView(
                child: switch (c.options) {
                  ScheduleOptionsLoading() => JitanLoadingState(label: context.t(AdminTextKeys.scheduleFormOptionsLoading)),
                  ScheduleOptionsFailed(:final failure) => _optionsError(context, failure),
                  ScheduleOptionsLoaded(:final options) => _step(context, options),
                },
              ),
            ),
          ],
        ),
        leadingActions: [
          JitanSecondaryButton(
            label: context.t(c.onFirstStep ? CommonTextKeys.cancel : CommonTextKeys.back),
            onPressed: c.submitting
                ? null
                : c.onFirstStep
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
        ScheduleStep.hours => _hours(context, options),
        ScheduleStep.attendance => _rules(context, options),
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

  /// What HR should know about the chosen group before going on.
  Widget? _groupBanner(BuildContext context) {
    final c = _controller;
    final group = c.group;
    if (group == null) return null;
    if (c.blocked) return ScheduleFormBanner.error(context.t(AdminTextKeys.scheduleFormBlocked, args: {'group': group.group.name}));
    if (c.conflict) {
      return ScheduleFormBanner.note(
        context.t(AdminTextKeys.scheduleFormConflict, args: {'group': group.group.name}),
        action: context.t(AdminTextKeys.scheduleFormConflictAction),
        onAction: _editExisting,
      );
    }
    if (c.employeesDiffer) return ScheduleFormBanner.warning(context.t(AdminTextKeys.scheduleFormDiffer, args: {'group': group.group.name}));
    return null;
  }

  /// Step 1 (Figma `1551:2`, per day `1551:207`): the group, the days, the
  /// hours and the break.
  List<Widget> _hours(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    final t = TranslationScope.of(context);
    final hint = context.t(AdminTextKeys.scheduleFormTimeHint);
    final start = context.t(AdminTextKeys.scheduleFormStart), finish = context.t(AdminTextKeys.scheduleFormFinish);
    final hoursRefused = c.fieldErrors.containsKey(ScheduleFormController.fieldHours);
    Widget range({
      required String? from,
      required String? to,
      required ValueChanged<String?> onFrom,
      required ValueChanged<String?> onTo,
      required String day,
    }) {
      // Which time is wrong, once the hours were refused: a missing one, or
      // a finish that is not after the start.
      final (fromMinutes, toMinutes) = (_minutesOf(from), _minutesOf(to));
      final badFrom = hoursRefused && fromMinutes == null;
      final badTo = hoursRefused && (toMinutes == null || (fromMinutes != null && toMinutes <= fromMinutes));
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          ScheduleTimeField(chip: true, hint: hint, value: from, onChanged: busy ? null : onFrom, semanticLabel: '$day $start', failed: badFrom),
          Text('–', style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
          ScheduleTimeField(chip: true, hint: hint, value: to, onChanged: busy ? null : onTo, semanticLabel: '$day $finish', failed: badTo),
        ],
      );
    }
    final hoursLabel = context.t(AdminTextKeys.scheduleRowHours);
    return [
      ?_groupBanner(context),
      JitanSettingsCard(
        rows: [
          if (!c.groupLocked)
            JitanSettingsRow(
              label: context.t(AdminTextKeys.scheduleRowGroup),
              info: context.t(AdminTextKeys.scheduleInfoGroup),
              value: JitanInlineSelect<int>(
                hintText: context.t(AdminTextKeys.scheduleFormGroupHint),
                value: c.groupId,
                options: [for (final g in c.groups) JitanSelectOption(value: g.group.id, label: g.group.name)],
                onChanged: busy ? null : c.selectGroup,
              ),
            ),
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
              value: range(from: c.start, to: c.finish, onFrom: c.setStart, onTo: c.setFinish, day: hoursLabel),
            )
          else
            for (final day in options.days)
              if (c.dayIds.contains(day.id))
                JitanSettingsRow(
                  label: dayLongName(t, day.weekday),
                  value: range(
                    from: c.hoursOf(day.id).start,
                    to: c.hoursOf(day.id).finish,
                    onFrom: (time) => c.setDayStart(day.id, time),
                    onTo: (time) => c.setDayFinish(day.id, time),
                    day: dayLongName(t, day.weekday),
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
      _fieldError(context, ScheduleFormController.fieldDays),
      _fieldError(context, ScheduleFormController.fieldHours),
      _fieldError(context, ScheduleFormController.fieldBreak),
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

  /// Step 2 (Figma `1552:12`): tolerance and rounding.
  List<Widget> _rules(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    final unit = context.t(AdminTextKeys.scheduleFormMinutesUnit);
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
          failed: c.fieldErrors.containsKey(field),
        ),
      );
    }

    Widget rounding(String labelKey, String infoKey, ScheduleRounding? value, ValueChanged<ScheduleRounding?> onChanged) =>
        JitanSettingsRow(
          label: context.t(labelKey),
          info: context.t(infoKey),
          value: ScheduleRoundingSelect(
            value: value,
            intervals: options.roundingIntervalMinutes,
            onChanged: busy ? null : onChanged,
          ),
        );

    return [
      JitanSettingsCard(
        rows: [
          minutes(AdminTextKeys.scheduleRowArrival, AdminTextKeys.scheduleInfoArrival, _arrival, ScheduleFormController.fieldArrival),
          minutes(AdminTextKeys.scheduleRowLeaving, AdminTextKeys.scheduleInfoLeaving, _leaving, ScheduleFormController.fieldLeaving),
          rounding(AdminTextKeys.scheduleRowStartRounding, AdminTextKeys.scheduleInfoStartRounding, c.startRounding, c.setStartRounding),
          rounding(AdminTextKeys.scheduleRowFinishRounding, AdminTextKeys.scheduleInfoFinishRounding, c.finishRounding, c.setFinishRounding),
        ],
      ),
      _fieldError(context, ScheduleFormController.fieldArrival),
      _fieldError(context, ScheduleFormController.fieldLeaving),
    ];
  }

  /// Step 3 (Figma `1552:201`): everything that will be saved.
  List<Widget> _review(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final t = TranslationScope.of(context);
    final variant = ScheduleVariant(
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
    );
    final group = c.group;
    return [
      JitanSettingsCard(
        rows: [
          if (!c.groupLocked && group != null)
            JitanSettingsRow(label: context.t(AdminTextKeys.scheduleRowGroup), value: JitanSettingsRow.text(group.group.name)),
          JitanSettingsRow(label: context.t(AdminTextKeys.scheduleRowWorkDays), value: JitanSettingsRow.text(workDaysText(t, variant))),
          JitanSettingsRow(label: context.t(AdminTextKeys.scheduleRowHours), value: JitanSettingsRow.text(workHoursText(t, variant))),
          JitanSettingsRow(
            label: context.t(AdminTextKeys.scheduleRowBreak),
            value: JitanSettingsRow.text(context.t(AdminTextKeys.scheduleFormLengthOption, args: {'minutes': c.breakLength ?? 0})),
          ),
          JitanSettingsRow(
            label: context.t(AdminTextKeys.scheduleRowTolerance),
            value: JitanSettingsRow.text(
              toleranceText(t, int.tryParse(c.arrivalTolerance.trim()) ?? 0, int.tryParse(c.leavingTolerance.trim()) ?? 0),
            ),
          ),
          JitanSettingsRow(
            label: context.t(AdminTextKeys.scheduleRowRounding),
            value: JitanSettingsRow.text(roundingShortText(t, c.startRounding, c.finishRounding)),
          ),
        ],
      ),
      if (group != null) ...[
        const SizedBox(height: 14),
        Text(
          context.tPlural(
            AdminTextKeys.scheduleReviewApplies,
            group.singleGroupEmployeeCount,
            args: {'group': group.group.name},
          ),
          style: _note,
        ),
      ],
    ];
  }

  String? _errorText(BuildContext context, String field) => switch (_controller.fieldErrors[field]) {
    null => null,
    (:final key, :final args) => context.t(key, args: args),
  };

  Widget _fieldError(BuildContext context, String field) => switch (_errorText(context, field)) {
    null => const SizedBox.shrink(),
    final text => Padding(
      padding: const EdgeInsets.only(top: 10),
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

  /// Minutes since midnight of a typed time, `null` when it is not one.
  static int? _minutesOf(String? time) => switch (tidyTime(time ?? '')) {
    null => null,
    final t => int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3)),
  };
}

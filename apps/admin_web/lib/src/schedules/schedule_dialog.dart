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

/// Figma `HR / Schedules — Create Work hours` (1317:2), `Create Break`
/// (1317:191), `Per-day hours` (1318:2), `Edit Work hours` (1317:362) and
/// the blocked, warning, conflict, saving and field-error states.
///
/// Differences from Figma, on purpose: the "View →" link of the warning is
/// left out (no screen lists the employees' differing schedules yet), and
/// times are picked in 5-minute steps.
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

  Future<void> _save() async {
    _controller
      ..arrivalTolerance = _arrival.text
      ..leavingTolerance = _leaving.text;
    final saved = await _controller.submit();
    if (saved != null && mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      final workHours = c.kind == ScheduleKind.workHours;
      return JitanModal(
        width: 740,
        title: context.t(c.editing ? AdminTextKeys.scheduleFormEditTitle : AdminTextKeys.scheduleFormCreateTitle),
        subtitle: context.t(workHours ? AdminTextKeys.scheduleFormWorkHoursSubtitle : AdminTextKeys.scheduleFormBreaksSubtitle),
        onClose: c.submitting ? null : () => Navigator.of(context).pop(),
        // Until a group and a day are chosen, the footer says why Save is off.
        footerNote: context.t(
          c.missingRequired && c.options is ScheduleOptionsLoaded
              ? AdminTextKeys.scheduleFormSaveHint
              : AdminTextKeys.scheduleFormFooter,
        ),
        // Switching type or per-day hours changes the height: animate it.
        body: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: switch (c.options) {
            ScheduleOptionsLoading() => SizedBox(
              height: 200,
              child: JitanLoadingState(label: context.t(AdminTextKeys.scheduleFormOptionsLoading)),
            ),
            ScheduleOptionsFailed(:final failure) => SizedBox(height: 240, child: _optionsError(context, failure)),
            ScheduleOptionsLoaded(:final options) => _form(context, options),
          },
        ),
        actions: [
          JitanPrimaryButton(
            label: context.t(AdminTextKeys.scheduleFormSave),
            busy: c.submitting,
            onPressed: c.canSave ? _save : null,
          ),
        ],
      );
    },
  );

  Widget _form(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    final group = c.group;
    final t = TranslationScope.of(context);
    final weekdays = [for (final day in options.days) if (day.weekday <= DateTime.friday) day.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        _sectionGap,
        _Section(
          title: context.t(AdminTextKeys.scheduleFormDays),
          trailing: TextButton(
            onPressed: busy ? null : () => c.selectDays(weekdays),
            child: Text(
              context.t(AdminTextKeys.scheduleFormWeekdays),
              style: JitanTextStyles.inputText.copyWith(fontWeight: FontWeight.w600, color: JitanColors.vermilion),
            ),
          ),
          child: Wrap(
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
        ),
        _fieldError(context, ScheduleFormController.fieldDays),
        _sectionGap,
        if (c.kind == ScheduleKind.workHours) ..._workHours(context, options) else ..._breaks(context, options),
        _fieldError(context, ScheduleFormController.fieldForm),
        if (c.failure case final failure?) ...[
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
  }

  List<Widget> _workHours(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    final t = TranslationScope.of(context);
    final selectedDays = [for (final day in options.days) if (c.dayIds.contains(day.id)) day];
    final startLabel = context.t(AdminTextKeys.scheduleFormStart);
    final finishLabel = context.t(AdminTextKeys.scheduleFormFinish);
    final hint = context.t(AdminTextKeys.scheduleFormTimeHint);
    final sameHours = ScheduleCheckRow(
      label: context.t(AdminTextKeys.scheduleFormSameHours),
      value: c.sameHours,
      onChanged: busy ? null : c.setSameHours,
    );
    final hours = ScheduleHoursTable(
      startLabel: startLabel,
      finishLabel: finishLabel,
      timeHint: hint,
      afterFirst: sameHours,
      lines: c.sameHours
          ? [(day: null, start: c.start, finish: c.finish, onStart: busy ? null : c.setStart, onFinish: busy ? null : c.setFinish)]
          : [
              for (final day in selectedDays)
                (
                  day: dayShortName(t, day.weekday),
                  start: c.hoursOf(day.id).start,
                  finish: c.hoursOf(day.id).finish,
                  onStart: busy ? null : (String? time) => c.setDayStart(day.id, time),
                  onFinish: busy ? null : (String? time) => c.setDayFinish(day.id, time),
                ),
            ],
    );
    final tolerance = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toleranceField(context, AdminTextKeys.scheduleFormArrivalTolerance, _arrival, ScheduleFormController.fieldArrival),
        const SizedBox(width: _toleranceGap),
        _toleranceField(context, AdminTextKeys.scheduleFormLeavingTolerance, _leaving, ScheduleFormController.fieldLeaving),
      ],
    );
    final hoursSection = _Section(
      title: context.t(c.sameHours ? AdminTextKeys.scheduleFormHours : AdminTextKeys.scheduleFormHoursByDay),
      child: hours,
    );
    final toleranceSection = _Section(title: context.t(AdminTextKeys.scheduleFormTolerance), child: tolerance);
    return [
      // Hours and attendance tolerance side by side; stacked when narrow.
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _inlineWidth
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: hoursSection),
                  const SizedBox(width: 24),
                  SizedBox(width: _toleranceWidth, child: toleranceSection),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [hoursSection, _sectionGap, toleranceSection],
              ),
      ),
      _fieldError(context, ScheduleFormController.fieldHours),
      _sectionGap,
      _Section(
        title: context.t(AdminTextKeys.scheduleFormRounding),
        child: ScheduleFieldColumns(
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
      ),
    ];
  }

  List<Widget> _breaks(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    return [
      _Section(
        title: context.t(AdminTextKeys.scheduleKindBreaks),
        child: Wrap(
          spacing: 30,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 150,
              child: ScheduleTimeField(
                label: context.t(AdminTextKeys.scheduleFormUsualTime),
                hint: context.t(AdminTextKeys.scheduleFormTimeHint),
                value: c.breakStart,
                onChanged: busy ? null : c.setBreakStart,
              ),
            ),
            SizedBox(
              width: 150,
              child: JitanSelectField<int>(
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
            ),
          ],
        ),
      ),
      _fieldError(context, ScheduleFormController.fieldBreak),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: JitanColors.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t(AdminTextKeys.scheduleFormBreakNoteTitle), style: JitanTextStyles.stateTitle.copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(context.t(AdminTextKeys.scheduleFormBreakNoteText), style: JitanTextStyles.stateMessage),
                ],
              ),
            ),
          ],
        ),
      ),
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

  /// Space between the form's sections; fields within a section sit closer.
  static const _sectionGap = SizedBox(height: 32);

  static const _toleranceGap = 16.0;
  static const _toleranceWidth = 130 * 2 + _toleranceGap;

  /// Hours (day, start, finish) + tolerance fit side by side from here.
  static const _inlineWidth = ScheduleHoursTable.dayWidth +
      ScheduleHoursTable.timeWidth * 2 +
      ScheduleHoursTable.dashWidth +
      24 +
      _toleranceWidth;

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

}

/// A titled block of the form, with an optional control on the right of
/// the title (e.g. "Mon–Fri", "Same hours every working day").
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(child: Text(title, style: JitanTextStyles.stateTitle)),
            ?trailing,
          ],
        ),
      ),
      const SizedBox(height: 10),
      child,
    ],
  );
}

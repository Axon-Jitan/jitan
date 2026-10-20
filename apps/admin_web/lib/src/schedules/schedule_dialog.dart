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
}) => showDialog<GroupSchedule>(
  context: context,
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
        footerNote: context.t(AdminTextKeys.scheduleFormFooter),
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
        const SizedBox(height: 24),
        JitanFieldLabel(
          label: context.t(AdminTextKeys.scheduleFormDays),
          child: Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final day in options.days)
                ScheduleDayToggle(
                  label: dayShortName(TranslationScope.of(context), day.weekday),
                  selected: c.dayIds.contains(day.id),
                  onPressed: busy ? null : () => c.toggleDay(day.id),
                ),
            ],
          ),
        ),
        _fieldError(context, ScheduleFormController.fieldDays),
        const SizedBox(height: 24),
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
    final selectedDays = [for (final day in options.days) if (c.dayIds.contains(day.id)) day];
    return [
      Text(
        context.t(c.sameHours ? AdminTextKeys.scheduleFormHours : AdminTextKeys.scheduleFormHoursByDay),
        style: _sectionTitle,
      ),
      const SizedBox(height: 8),
      ScheduleCheckRow(
        label: context.t(AdminTextKeys.scheduleFormSameHours),
        value: c.sameHours,
        onChanged: busy ? null : c.setSameHours,
      ),
      const SizedBox(height: 16),
      if (c.sameHours)
        ScheduleFieldColumns(
          children: [
            ScheduleTimeField(label: context.t(AdminTextKeys.scheduleFormStart), value: c.start, onChanged: busy ? null : c.setStart),
            ScheduleTimeField(label: context.t(AdminTextKeys.scheduleFormFinish), value: c.finish, onChanged: busy ? null : c.setFinish),
          ],
        )
      else
        for (final day in selectedDays) ...[
          ScheduleFieldColumns(
            children: [
              ScheduleTimeField(
                label: '${dayShortName(TranslationScope.of(context), day.weekday)} · ${context.t(AdminTextKeys.scheduleFormStart)}',
                value: c.hoursOf(day.id).start,
                onChanged: busy ? null : (time) => c.setDayStart(day.id, time),
              ),
              ScheduleTimeField(
                label: '${dayShortName(TranslationScope.of(context), day.weekday)} · ${context.t(AdminTextKeys.scheduleFormFinish)}',
                value: c.hoursOf(day.id).finish,
                onChanged: busy ? null : (time) => c.setDayFinish(day.id, time),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      _fieldError(context, ScheduleFormController.fieldHours),
      const SizedBox(height: 24),
      Text(context.t(AdminTextKeys.scheduleFormTolerance), style: _sectionTitle),
      const SizedBox(height: 12),
      ScheduleFieldColumns(
        children: [
          _toleranceField(context, AdminTextKeys.scheduleFormArrivalTolerance, _arrival, ScheduleFormController.fieldArrival, options),
          _toleranceField(context, AdminTextKeys.scheduleFormLeavingTolerance, _leaving, ScheduleFormController.fieldLeaving, options),
        ],
      ),
      const SizedBox(height: 24),
      Text(context.t(AdminTextKeys.scheduleFormRounding), style: _sectionTitle),
      const SizedBox(height: 12),
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
    ];
  }

  List<Widget> _breaks(BuildContext context, ScheduleOptions options) {
    final c = _controller;
    final busy = c.submitting;
    return [
      ScheduleFieldColumns(
        children: [
          ScheduleTimeField(
            label: context.t(AdminTextKeys.scheduleFormUsualTime),
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
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 16, color: JitanColors.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t(AdminTextKeys.scheduleFormBreakNoteTitle), style: JitanTextStyles.stateTitle.copyWith(fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(context.t(AdminTextKeys.scheduleFormBreakNoteText), style: JitanTextStyles.stateMessage.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _toleranceField(
    BuildContext context,
    String labelKey,
    TextEditingController controller,
    String field,
    ScheduleOptions options,
  ) => JitanTextField(
    label: context.t(labelKey),
    controller: controller,
    enabled: !_controller.submitting,
    keyboardType: TextInputType.number,
    hintText: context.t(AdminTextKeys.scheduleFormToleranceHint, args: {'max': options.maxToleranceMinutes}),
    errorText: _errorText(context, field),
    maxLength: 2,
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

  static final _sectionTitle = JitanTextStyles.stateTitle.copyWith(fontSize: 14);
}

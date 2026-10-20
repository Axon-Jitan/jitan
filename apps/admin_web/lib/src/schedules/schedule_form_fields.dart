import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'schedule_form_controller.dart';
import 'schedule_summary_text.dart';

/// Two fields side by side (Figma), one above the other when narrow.
class ScheduleFieldColumns extends StatelessWidget {
  const ScheduleFieldColumns({super.key, required this.children});

  final List<Widget> children;

  static const _gap = 30.0;
  static const _minColumnWidth = 260.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns = constraints.maxWidth >= _minColumnWidth * 2 + _gap;
      final width = twoColumns ? (constraints.maxWidth - _gap) / 2 : constraints.maxWidth;
      return Wrap(
        spacing: _gap,
        runSpacing: 16,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

/// A weekday chip of "Working days": chosen days are filled dark, the
/// others plain, so the choice reads at a glance.
class ScheduleDayToggle extends StatelessWidget {
  const ScheduleDayToggle({super.key, required this.label, required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? JitanColors.ink : JitanColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? JitanColors.ink : JitanColors.inputBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: SizedBox(
          width: 80,
          height: 40,
          child: Center(
            child: Text(
              label,
              style: JitanTextStyles.inputText.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? JitanColors.surface : JitanColors.ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// One line of a [ScheduleHoursTable]: a day, its start and its finish.
typedef ScheduleHoursLine = ({
  String day,
  String? start,
  String? finish,
  ValueChanged<String?>? onStart,
  ValueChanged<String?>? onFinish,
});

/// Hours per working day (Figma `Daily hours` 1367:2): "Day", "Start" and
/// "Finish" as column headings once, then one shaded-or-plain line per day.
class ScheduleHoursTable extends StatelessWidget {
  const ScheduleHoursTable({
    super.key,
    required this.lines,
    required this.dayLabel,
    required this.startLabel,
    required this.finishLabel,
    required this.timeHint,
  });

  final List<ScheduleHoursLine> lines;
  final String dayLabel;
  final String startLabel;
  final String finishLabel;
  final String timeHint;

  static const _dayWidth = 92.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget day, Widget start, Widget finish) => Row(
      children: [
        SizedBox(width: _dayWidth, child: day),
        Expanded(child: start),
        const SizedBox(width: _gap),
        Expanded(child: finish),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: row(
            Text(dayLabel, style: JitanTextStyles.fieldLabel),
            Text(startLabel, style: JitanTextStyles.fieldLabel),
            Text(finishLabel, style: JitanTextStyles.fieldLabel),
          ),
        ),
        const SizedBox(height: JitanDimensions.fieldLabelGap),
        for (final (index, line) in lines.indexed)
          DecoratedBox(
            decoration: BoxDecoration(
              color: index.isOdd ? JitanColors.warmWhite : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: row(
                Text(line.day, style: JitanTextStyles.inputText.copyWith(fontWeight: FontWeight.w500)),
                ScheduleTimeField(hint: timeHint, value: line.start, onChanged: line.onStart),
                ScheduleTimeField(hint: timeHint, value: line.finish, onChanged: line.onFinish),
              ),
            ),
          ),
      ],
    );
  }
}

/// The wizard's progress: one bar per step, filled up to the current one,
/// with the step's name under it (the current one bold).
class ScheduleStepper extends StatelessWidget {
  const ScheduleStepper({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, label) in labels.indexed) ...[
        if (index > 0) const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            selected: index == current,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: index <= current ? JitanColors.vermilion : JitanColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: index == current
                      ? JitanTextStyles.fieldLabel.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w600)
                      : JitanTextStyles.fieldLabel,
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

/// A whole number of minutes with "min" inside the box (tolerances).
class ScheduleMinutesField extends StatelessWidget {
  const ScheduleMinutesField({
    super.key,
    required this.label,
    required this.controller,
    required this.unit,
    required this.enabled,
    this.errorText,
    this.width,
  });

  /// `null` fills the available width.
  final double? width;
  final String label;
  final TextEditingController controller;
  final String unit;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final error = errorText;
    // Fixed width: a long (translated) label wraps instead of widening the row.
    return SizedBox(
      width: width,
      child: JitanFieldLabel(
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width,
              height: JitanDimensions.fieldHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: enabled ? JitanColors.surface : JitanColors.disabledFill,
                borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
                border: Border.all(color: error == null ? JitanColors.inputBorder : JitanColors.error),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      style: JitanTextStyles.inputText,
                      cursorColor: JitanColors.ink,
                      decoration: const InputDecoration.collapsed(hintText: null).copyWith(counterText: ''),
                    ),
                  ),
                  Text(unit, style: JitanTextStyles.inputHint),
                ],
              ),
            ),
            if (error != null) ...[const SizedBox(height: 6), Text(error, style: JitanTextStyles.fieldError)],
          ],
        ),
      ),
    );
  }
}

class ScheduleCheckRow extends StatelessWidget {
  const ScheduleCheckRow({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onChanged == null ? null : () => onChanged!(!value),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: JitanTextStyles.inputText)),
      ],
    ),
  );
}

class ScheduleTimeField extends StatelessWidget {
  const ScheduleTimeField({super.key, this.label, required this.value, required this.onChanged, this.hint});

  /// `null` in a table row, where the column heading names the field.
  final String? label;
  final String? value;
  final ValueChanged<String?>? onChanged;

  /// Shown, light, while no time is chosen (e.g. "--:--").
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return JitanSelectField<String>(
      label: label,
      value: current,
      hintText: hint,
      options: [
        for (final time in {...ScheduleFormController.timeChoices, ?current}.toList()..sort())
          JitanSelectOption(value: time, label: time),
      ],
      onChanged: onChanged,
    );
  }
}

/// No rounding, or up / down by one of the intervals.
class ScheduleRoundingField extends StatelessWidget {
  const ScheduleRoundingField({
    super.key,
    required this.label,
    required this.value,
    required this.intervals,
    required this.onChanged,
  });

  final String label;
  final ScheduleRounding? value;
  final List<int> intervals;
  final ValueChanged<ScheduleRounding?>? onChanged;

  static String _keyOf(ScheduleRounding? r) => r == null ? 'none' : '${r.roundUp ? 'up' : 'down'}:${r.intervalMinutes}';

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final choices = <String, ScheduleRounding?>{
      'none': null,
      for (final minutes in intervals) ...{
        'up:$minutes': ScheduleRounding(intervalMinutes: minutes, roundUp: true),
        'down:$minutes': ScheduleRounding(intervalMinutes: minutes, roundUp: false),
      },
    };
    return JitanSelectField<String>(
      label: label,
      value: _keyOf(value),
      options: [
        for (final MapEntry(:key, :value) in choices.entries)
          JitanSelectOption(value: key, label: roundingText(t, value)),
      ],
      onChanged: onChanged == null ? null : (key) => onChanged!(choices[key]),
    );
  }
}

/// The message strip at the top of the form (Figma blocked / warning /
/// conflict states).
class ScheduleFormBanner extends StatelessWidget {
  const ScheduleFormBanner._(this.text, this.background, this.foreground, {super.key, this.action, this.onAction});

  const ScheduleFormBanner.error(String text, {Key? key})
    : this._(text, JitanColors.errorSurface, JitanColors.errorStrong, key: key);
  const ScheduleFormBanner.warning(String text, {Key? key})
    : this._(text, JitanColors.warningSurface, JitanColors.ink, key: key);
  const ScheduleFormBanner.note(String text, {Key? key, required String action, required VoidCallback onAction})
    : this._(text, JitanColors.noteSurface, JitanColors.ink, key: key, action: action, onAction: onAction);

  final String text;
  final Color background;
  final Color foreground;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(text, style: JitanTextStyles.stateTitle.copyWith(fontSize: 16, color: foreground)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
              child: Text(
                '$action →',
                style: JitanTextStyles.stateTitle.copyWith(fontSize: 16, color: JitanColors.vermilion),
              ),
            ),
        ],
      ),
    ),
  );
}

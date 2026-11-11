import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'schedule_summary_text.dart';

/// The height of every step of the schedule and Create group wizards
/// (product owner, 2026-11-11: the pop-ups must not jump between steps):
/// room for the employee list of Create group; less on a short window, so
/// the pop-up still fits.
double wizardStepHeight(Size screen) => (screen.height - 330).clamp(260.0, 470.0);

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

/// A time HR types in ("0730" or "7:30" becomes "07:30"), in the same
/// outlined box as the other fields. [onChanged] gets the text as typed;
/// the form checks it is a valid HH:mm.
class ScheduleTimeField extends StatefulWidget {
  const ScheduleTimeField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.info,
    this.chip = false,
    this.semanticLabel,
    this.failed = false,
  });

  /// A [chip] outlined in red: this time is refused (the message is under
  /// the card, Figma `1553:752`).
  final bool failed;

  /// A small soft chip for a settings row (Figma `1551:2`, "07:30"),
  /// instead of an outlined field.
  final bool chip;

  /// What a screen reader says for a [chip] ("Monday start").
  final String? semanticLabel;

  /// `null` in a table row, where the column heading names the field.
  final String? label;

  /// The ⓘ by the label: what the field means, with an example.
  final String? info;
  final String? value;
  final ValueChanged<String?>? onChanged;

  /// Shown, light, while the field is empty (e.g. "--:--").
  final String? hint;

  @override
  State<ScheduleTimeField> createState() => _ScheduleTimeFieldState();
}

class _ScheduleTimeFieldState extends State<ScheduleTimeField> {
  late final _controller = TextEditingController(text: widget.value ?? '');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Tidy the time when HR leaves the field: "730" → "07:30".
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      final tidy = tidyTime(_controller.text);
      if (tidy != null && tidy != _controller.text) {
        _controller.text = tidy;
        widget.onChanged?.call(tidy);
      }
    });
  }

  @override
  void didUpdateWidget(ScheduleTimeField old) {
    super.didUpdateWidget(old);
    // Filled in from outside (edit, Back): show it, unless HR is typing.
    if (!_focus.hasFocus && (widget.value ?? '') != _controller.text) _controller.text = widget.value ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    if (widget.chip) return _chip(enabled);
    final box = Container(
      height: JitanDimensions.fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: enabled ? JitanColors.surface : JitanColors.disabledFill,
        borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
        border: Border.all(color: JitanColors.inputBorder),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: enabled,
        keyboardType: TextInputType.datetime,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:.]')), LengthLimitingTextInputFormatter(5)],
        style: JitanTextStyles.inputText,
        cursorColor: JitanColors.ink,
        decoration: InputDecoration.collapsed(hintText: widget.hint, hintStyle: JitanTextStyles.inputHint),
        onChanged: (text) => widget.onChanged?.call(tidyTime(text) ?? text),
      ),
    );
    final label = widget.label;
    return label == null ? box : JitanFieldLabel(label: label, info: widget.info, child: box);
  }

  Widget _chip(bool enabled) => Semantics(
    label: widget.semanticLabel,
    textField: true,
    child: Container(
      width: 66,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: JitanColors.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: widget.failed ? Border.all(color: JitanColors.error) : null,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: enabled,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:.]')), LengthLimitingTextInputFormatter(5)],
        style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w500),
        cursorColor: JitanColors.ink,
        decoration: InputDecoration.collapsed(hintText: widget.hint, hintStyle: JitanTextStyles.inputHint),
        onChanged: (text) => widget.onChanged?.call(tidyTime(text) ?? text),
      ),
    ),
  );
}

/// A round one-letter day button ("M"), dark when chosen (Figma `1551:2`,
/// as the Repeat days of the iPhone Clock app).
class ScheduleDayDot extends StatelessWidget {
  const ScheduleDayDot({super.key, required this.letter, required this.name, required this.selected, required this.onPressed});

  final String letter;

  /// The day's name, for the tooltip and screen readers ("Mon").
  final String name;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: name,
    child: Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: selected ? JitanColors.ink : JitanColors.inputFill,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Text(
                letter,
                style: JitanTextStyles.tableCell.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? JitanColors.surface : JitanColors.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A whole number of minutes in a soft chip with "min" (Figma `1552:12`,
/// "5 min"), for a settings row.
class ScheduleMinutesChip extends StatelessWidget {
  const ScheduleMinutesChip({
    super.key,
    required this.controller,
    required this.unit,
    required this.enabled,
    required this.semanticLabel,
    this.failed = false,
  });

  final TextEditingController controller;
  final String unit;
  final bool enabled;
  final String semanticLabel;

  /// Outlined in red: the value is refused (the message is under the card).
  final bool failed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    textField: true,
    child: Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: JitanColors.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: failed ? Border.all(color: JitanColors.error) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          SizedBox(
            width: 22,
            child: TextField(
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.end,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w500),
              cursorColor: JitanColors.ink,
              decoration: const InputDecoration.collapsed(hintText: null),
            ),
          ),
          Text(unit, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}

/// "07:30" for "0730", "730", "7:30", "7.30" or "07:30"; `null` when it is
/// not a time of day.
String? tidyTime(String text) {
  final digits = text.replaceAll(RegExp(r'[:.]'), '');
  final separated = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(text);
  final (hours, minutes) = switch (separated) {
    final m? => (int.parse(m.group(1)!), int.parse(m.group(2)!)),
    null when RegExp(r'^\d{3,4}$').hasMatch(digits) && digits == text => (
      int.parse(digits.substring(0, digits.length - 2)),
      int.parse(digits.substring(digits.length - 2)),
    ),
    _ => (-1, -1),
  };
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

/// The key of a rounding choice: "none", "up:15" or "down:15".
String _roundingKey(ScheduleRounding? r) => r == null ? 'none' : '${r.roundUp ? 'up' : 'down'}:${r.intervalMinutes}';

/// The soft note above the card (Figma `HR / Schedules V3`: blocked
/// `1553:257`, already has one `1553:423`, employees differ `1553:588`).
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
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(text, style: JitanTextStyles.tableCell.copyWith(color: foreground)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
              child: Text(
                '$action →',
                style: JitanTextStyles.tableCell.copyWith(fontWeight: FontWeight.w500, color: JitanColors.vermilion),
              ),
            ),
        ],
      ),
    ),
  );
}

/// No rounding, or up / down by one of the intervals, as plain text with a
/// chevron for a settings row (Figma `1552:12`, "Up, every 15 min ⌄").
class ScheduleRoundingSelect extends StatelessWidget {
  const ScheduleRoundingSelect({super.key, required this.value, required this.intervals, required this.onChanged});

  final ScheduleRounding? value;
  final List<int> intervals;
  final ValueChanged<ScheduleRounding?>? onChanged;

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
    return JitanInlineSelect<String>(
      value: _roundingKey(value),
      options: [
        for (final MapEntry(:key, :value) in choices.entries) JitanSelectOption(value: key, label: roundingText(t, value)),
      ],
      onChanged: onChanged == null ? null : (key) => onChanged!(choices[key]),
    );
  }
}

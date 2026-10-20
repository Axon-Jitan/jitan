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

/// A weekday chip of "Working days".
class ScheduleDayToggle extends StatelessWidget {
  const ScheduleDayToggle({super.key, required this.label, required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  static const _selectedFill = Color(0xFFEFF2F0);
  static const _selectedBorder = Color(0xFFBFCCC4);
  static const _idleFill = Color(0xFFF6F6F5);

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? _selectedFill : _idleFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: selected ? const BorderSide(color: _selectedBorder) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onPressed,
        child: SizedBox(
          width: 89,
          height: 36,
          child: Center(
            child: Text(
              label,
              style: JitanTextStyles.stateTitle.copyWith(color: selected ? JitanColors.ink : JitanColors.inkMuted),
            ),
          ),
        ),
      ),
    ),
  );
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
        Checkbox(value: value, onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false)),
        Text(label, style: JitanTextStyles.inputText.copyWith(fontSize: 13)),
      ],
    ),
  );
}

class ScheduleTimeField extends StatelessWidget {
  const ScheduleTimeField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final String? value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return JitanSelectField<String>(
      label: label,
      value: current,
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
  const ScheduleRoundingField({super.key, required this.label, required this.value, required this.intervals, required this.onChanged});

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
      options: [for (final MapEntry(:key, :value) in choices.entries) JitanSelectOption(value: key, label: roundingText(t, value))],
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
          Text(text, style: JitanTextStyles.stateTitle.copyWith(fontSize: 14, color: foreground)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
              child: Text('$action →', style: JitanTextStyles.stateTitle.copyWith(fontSize: 14, color: JitanColors.vermilion)),
            ),
        ],
      ),
    ),
  );
}

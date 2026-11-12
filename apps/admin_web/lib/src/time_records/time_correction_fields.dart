import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'rounded_time_controller.dart';
import 'time_correction_failure.dart';
import 'time_input_formatter.dart';

/// A time HR types (`HH:mm`) in the Actual column of a correction card
/// (Figma `1566:272`, `1566:788`): small, white, outlined in red when the
/// time is refused (the message is under the card).
class TimeCardInput extends StatelessWidget {
  const TimeCardInput({super.key, required this.time, required this.semanticLabel, this.failed = false, this.enabled = true});

  final RoundedTimeController time;

  /// What a screen reader says ("Start").
  final String semanticLabel;
  final bool failed;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    textField: true,
    child: Container(
      width: 96,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: JitanColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: failed ? JitanColors.error : JitanColors.inputBorder),
      ),
      child: TextField(
        controller: time.text,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: const [TimeInputFormatter()],
        style: JitanTextStyles.inputText,
        cursorColor: JitanColors.ink,
        decoration: InputDecoration.collapsed(
          hintText: context.t(AdminTextKeys.timeCorrectTimeHint),
          hintStyle: JitanTextStyles.inputHint,
        ),
      ),
    ),
  );
}

/// What [time] counts as after rounding, from the server: "16:45", or "—"
/// until it is known.
class RoundedTimeValue extends StatelessWidget {
  const RoundedTimeValue({super.key, required this.time});

  final RoundedTimeController time;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: time,
    builder: (context, _) {
      final rounded = time.rounded;
      return Text(
        rounded ?? '—',
        style: (rounded == null ? JitanTextStyles.tableCell : JitanTextStyles.tableCellStrong).copyWith(
          fontSize: 15,
          color: rounded == null ? JitanColors.inkMuted : JitanColors.ink,
        ),
      );
    },
  );
}

/// The amber line under the card when no schedule with rounding applies to
/// the day: the rounded time stays empty.
class NoRoundingHint extends StatelessWidget {
  const NoRoundingHint({super.key, required this.times});

  final List<RoundedTimeController> times;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(times),
    builder: (context, _) => !times.any((t) => t.noRounding)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.t(AdminTextKeys.timeCorrectNoRounding),
              style: JitanTextStyles.stateMessage.copyWith(fontSize: 12, color: JitanColors.warning),
            ),
          ),
  );
}

/// A refused time, said under the card.
class TimeCardError extends StatelessWidget {
  const TimeCardError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: JitanTextStyles.fieldError));
}

/// A failed save shown above the buttons.
class TimeCorrectionMessage extends StatelessWidget {
  const TimeCorrectionMessage({super.key, required this.failure});

  final MessageFailure failure;

  @override
  Widget build(BuildContext context) => JitanInlineError(
    title: context.t(failure.title),
    message: failure.message == null ? null : context.t(failure.message!),
  );
}

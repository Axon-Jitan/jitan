import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'rounded_time_controller.dart';
import 'time_correction_failure.dart';
import 'time_input_formatter.dart';

/// A time HR types (`HH:mm`), from the correction windows (160:220, 272:457).
class TimeInputField extends StatelessWidget {
  const TimeInputField({super.key, required this.label, required this.time, this.errorText});

  final String label;
  final RoundedTimeController time;
  final String? errorText;

  @override
  Widget build(BuildContext context) => JitanTextField(
    label: label,
    controller: time.text,
    hintText: context.t(AdminTextKeys.timeCorrectTimeHint),
    errorText: errorText,
    keyboardType: TextInputType.number,
    inputFormatters: const [TimeInputFormatter()],
  );
}

/// What [time] counts as after rounding, calculated by the server: a grey
/// field HR can not edit (Figma 272:457 "Rounded finish").
class RoundedTimeField extends StatelessWidget {
  const RoundedTimeField({super.key, required this.label, required this.time});

  final String label;
  final RoundedTimeController time;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: time,
    builder: (context, _) => JitanFieldLabel(
      label: label,
      child: Container(
        height: JitanDimensions.fieldHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: JitanColors.inputFill,
          borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
          border: Border.all(color: JitanColors.inputBorder),
        ),
        child: Text(time.rounded ?? '—', style: JitanTextStyles.inputText),
      ),
    ),
  );
}

/// The small grey line under the rounded field, or the reason it is empty.
class RoundedTimeHint extends StatelessWidget {
  const RoundedTimeHint({super.key, required this.times});

  final List<RoundedTimeController> times;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(times),
    builder: (context, _) {
      final noRounding = times.any((t) => t.noRounding);
      return Text(
        context.t(noRounding ? AdminTextKeys.timeCorrectNoRounding : AdminTextKeys.timeCorrectRoundedHint),
        style: JitanTextStyles.stateMessage.copyWith(
          fontSize: 12,
          color: noRounding ? JitanColors.warning : JitanColors.inkMuted,
        ),
      );
    },
  );
}

/// Two fields side by side, or one above the other on a narrow window.
class TimeFieldPair extends StatelessWidget {
  const TimeFieldPair({super.key, required this.first, required this.second, this.maxWidth = double.infinity});

  final Widget first;
  final Widget second;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 400
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [first, const SizedBox(height: 14), second])
        : Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: first), const SizedBox(width: 20), Expanded(child: second)],
              ),
            ),
          ),
  );
}

/// The blue "Audit trail" box and similar notes (Figma 160:220, 160:338).
class TimeCorrectionNote extends StatelessWidget {
  const TimeCorrectionNote({super.key, required this.text, this.title, this.color = JitanColors.info, this.background = JitanColors.infoSurface});

  final String? title;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: JitanTextStyles.tableCellStrong.copyWith(color: color, fontSize: 13)),
          const SizedBox(height: 6),
        ],
        Text(text, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12, color: color)),
      ],
    ),
  );
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

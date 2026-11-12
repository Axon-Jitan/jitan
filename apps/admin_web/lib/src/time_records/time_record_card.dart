import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// One line of a [TimeRecordCard]: what it is ("Start"), an optional small
/// line under it ("Automatic", "Not registered"), and its values.
class TimeRecordCardRow {
  const TimeRecordCardRow({required this.label, required this.values, this.detail, this.detailColor});

  final String label;
  final String? detail;
  final Color? detailColor;
  final List<Widget> values;
}

/// The soft grey card of the Time records pop-ups (Figma `1566:2`,
/// `1566:272`, `1566:788`, `1566:1040`): small column headings, then a row
/// per time with its values in fixed columns, thin lines between them.
class TimeRecordCard extends StatelessWidget {
  const TimeRecordCard({super.key, required this.widths, required this.rows, this.headings});

  /// The width of each value column; the label takes the rest.
  final List<double> widths;
  final List<String>? headings;
  final List<TimeRecordCardRow> rows;

  /// A time or duration as the card shows it: [strong] for what counts,
  /// [muted] for what does not (yet).
  static Widget value(String text, {bool strong = false, bool muted = false}) => Text(
    text,
    maxLines: 1,
    style: (strong ? JitanTextStyles.tableCellStrong : JitanTextStyles.tableCell).copyWith(
      fontSize: 15,
      color: muted ? JitanColors.inkMuted : JitanColors.ink,
    ),
  );

  static const _line = Divider(height: 1, thickness: 1, color: JitanColors.cardBorder);

  @override
  Widget build(BuildContext context) {
    final headings = this.headings;
    return LayoutBuilder(builder: (context, constraints) => _card(headings, _fitted(constraints.maxWidth - 40)));
  }

  /// The value columns, narrower on a phone so the label keeps room.
  List<double> _fitted(double inner) {
    final total = widths.fold(0.0, (a, b) => a + b);
    final room = inner - _labelMin;
    return total <= room ? widths : [for (final w in widths) w * room / total];
  }

  static const _labelMin = 72.0;

  Widget _card(List<String>? headings, List<double> widths) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(color: JitanColors.tableHeader, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headings != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: _columns(widths, const SizedBox.shrink(), [
                for (final heading in headings)
                  Text(heading, maxLines: 1, style: JitanTextStyles.tableCell.copyWith(fontSize: 12, color: JitanColors.inkMuted)),
              ]),
            ),
          for (final (i, row) in rows.indexed) ...[
            if (i > 0 || headings != null) _line,
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: _columns(widths, _label(row), row.values)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(TimeRecordCardRow row) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(row.label, style: JitanTextStyles.tableCell.copyWith(fontSize: 15, color: JitanColors.ink, fontWeight: FontWeight.w500)),
      if (row.detail case final detail?) ...[
        const SizedBox(height: 2),
        Text(detail, style: JitanTextStyles.tableCell.copyWith(fontSize: 12, color: row.detailColor ?? JitanColors.inkMuted)),
      ],
    ],
  );

  Widget _columns(List<double> widths, Widget label, List<Widget> values) => Row(
    children: [
      Expanded(child: Align(alignment: Alignment.centerLeft, child: label)),
      for (final (i, value) in values.indexed)
        SizedBox(width: widths[i], child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: value))),
    ],
  );
}

/// The small ⓘ line at the bottom of a Time records pop-up ("What was
/// registered is always kept.").
class TimeRecordNote extends StatelessWidget {
  const TimeRecordNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.info_outline, size: 14, color: JitanColors.inkMuted)),
      Expanded(child: Text(text, style: JitanTextStyles.stateMessage.copyWith(fontSize: 13))),
    ],
  );
}

/// A soft coloured box with one sentence: amber for what HR should know
/// before saving ("The day won’t count as work…"), grey otherwise.
class TimeRecordNotice extends StatelessWidget {
  const TimeRecordNotice(this.text, {super.key, this.warning = true});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: warning ? JitanColors.warningSurface : JitanColors.noteSurface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: JitanTextStyles.stateMessage.copyWith(fontSize: 13, color: warning ? JitanColors.warning : JitanColors.ink),
    ),
  );
}

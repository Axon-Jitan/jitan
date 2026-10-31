import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../reports/report_text.dart';
import 'dashboard_text.dart';

/// Registered hours per bar with a tick at what was planned; the exact
/// numbers on hover. One scale for both, in hours.
class DashboardHoursChart extends StatelessWidget {
  const DashboardHoursChart({super.key, required this.buckets, required this.size});

  final List<DashboardHoursBucket> buckets;
  final DashboardBucketSize size;

  static const _axisWidth = 40.0;
  static const _baseline = 152.0;
  static const _height = 176.0;

  /// The tallest bar's height; the room above it holds a planned tick.
  static const _tallest = 133.0;
  static const _maxBarWidth = 24.0;
  static const _labelWidth = 48.0;

  /// The largest round step at most [hours].
  static double _roundStep(double hours) {
    final power = math.pow(10, (math.log(hours) / math.ln10).floor()).toDouble();
    return [5, 3, 2.5, 2, 1].map((m) => m * power).firstWhere((step) => step <= hours, orElse: () => power);
  }

  static List<int> _axisMinutes(int top) {
    if (top == 0) return const [0];
    final step = (math.max(_roundStep(top / 120), 1) * 60).round();
    return [0, step, if (step * 2 <= top) step * 2];
  }

  String _label(BuildContext context, DashboardHoursBucket bucket) => switch (size) {
    DashboardBucketSize.month => context.t(CommonTextKeys.monthShort[bucket.from.month - 1]),
    DashboardBucketSize.day when buckets.length <= 7 => context.t(CommonTextKeys.weekdayShort[bucket.from.weekday - 1]),
    _ => DashboardText.shortDate(context, bucket.from),
  };

  String _tooltip(BuildContext context, DashboardHoursBucket bucket) => context.t(
    AdminTextKeys.dashboardBarTooltip,
    args: {
      'date': DashboardText.range(context, bucket.from, bucket.to),
      'registered': ReportText.hours(context, bucket.registeredMinutes),
      'planned': ReportText.hours(context, bucket.plannedMinutes),
    },
  );

  @override
  Widget build(BuildContext context) {
    final top = buckets.fold(0, (most, b) => math.max(most, math.max(b.registeredMinutes, b.plannedMinutes)));
    double heightOf(int minutes) => top == 0 ? 0 : minutes / top * _tallest;
    final labelStyle = JitanTextStyles.tableCell.copyWith(fontSize: 12, color: JitanColors.inkMuted);
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plot = constraints.maxWidth - _axisWidth;
          final step = plot / buckets.length;
          final barWidth = math.min(_maxBarWidth, math.max(step - 2, 2.0));
          final tickWidth = math.min(barWidth + 8, math.max(step - 2, 2.0));
          final labelEvery = math.max((_labelWidth / step).ceil(), 1);
          return Stack(
            children: [
              for (final minutes in _axisMinutes(top)) ...[
                Positioned(
                  left: _axisWidth,
                  right: 0,
                  top: _baseline - heightOf(minutes),
                  child: Container(height: 1, color: JitanColors.inputBorder),
                ),
                Positioned(
                  left: 0,
                  top: _baseline - heightOf(minutes) - 8,
                  child: Text(minutes == 0 ? '0' : DashboardText.hours(context, minutes), style: labelStyle),
                ),
              ],
              for (final (i, bucket) in buckets.indexed) ...[
                Positioned(
                  left: _axisWidth + i * step,
                  width: step,
                  top: 0,
                  height: _baseline,
                  child: Tooltip(
                    message: _tooltip(context, bucket),
                    waitDuration: Duration.zero,
                    child: ColoredBox(
                      color: Colors.transparent,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          if (bucket.registeredMinutes > 0)
                            Container(
                              width: barWidth,
                              height: math.max(heightOf(bucket.registeredMinutes), 2),
                              decoration: BoxDecoration(
                                color: JitanColors.ink,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          if (bucket.plannedMinutes > 0)
                            Positioned(
                              bottom: heightOf(bucket.plannedMinutes) + 5,
                              child: Container(width: tickWidth, height: 2, color: JitanColors.chartAmber),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (i % labelEvery == 0)
                  Positioned(
                    left: _axisWidth + (i + .5) * step - _labelWidth / 2,
                    width: _labelWidth,
                    top: _baseline + 6,
                    child: Text(
                      _label(context, bucket),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: labelStyle,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The chart's two series.
class DashboardHoursLegend extends StatelessWidget {
  const DashboardHoursLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = JitanTextStyles.tableCell.copyWith(fontSize: 12, color: JitanColors.inkMuted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: JitanColors.ink, borderRadius: BorderRadius.circular(3)),
          child: const SizedBox.square(dimension: 10),
        ),
        const SizedBox(width: 10),
        Text(context.t(AdminTextKeys.dashboardRegistered), style: style),
        const SizedBox(width: 10),
        Container(width: 14, height: 2, color: JitanColors.chartAmber),
        const SizedBox(width: 10),
        Text(context.t(AdminTextKeys.dashboardPlanned), style: style),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'dashboard_text.dart';

/// Employees per company, largest first.
class DashboardCompanyBars extends StatelessWidget {
  const DashboardCompanyBars({super.key, required this.companies});

  final List<DashboardCompany> companies;

  @override
  Widget build(BuildContext context) {
    final sorted = [...companies]..sort((a, b) => b.employees.compareTo(a.employees));
    final most = sorted.fold(0, (most, c) => math.max(most, c.employees));
    return Column(
      spacing: 14,
      children: [
        for (final company in sorted)
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(company.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: most == 0 ? 0 : company.employees / most,
                    minHeight: 14,
                    color: JitanColors.ink,
                    backgroundColor: JitanColors.chartTrack,
                    stopIndicatorColor: Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 40,
                child: Text(
                  DashboardText.number(company.employees),
                  textAlign: TextAlign.right,
                  style: JitanTextStyles.tableCellStrong,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

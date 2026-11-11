import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'dashboard_text.dart';

/// Employees per company, largest first. A row highlights under the pointer
/// and opens that company's employees.
class DashboardCompanyBars extends StatefulWidget {
  const DashboardCompanyBars({super.key, required this.companies, required this.onOpen});

  final List<DashboardCompany> companies;
  final ValueChanged<DashboardCompany> onOpen;

  @override
  State<DashboardCompanyBars> createState() => _DashboardCompanyBarsState();
}

class _DashboardCompanyBarsState extends State<DashboardCompanyBars> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.companies]..sort((a, b) => b.employees.compareTo(a.employees));
    final most = sorted.fold(0, (most, c) => math.max(most, c.employees));
    return Column(
      spacing: 2,
      children: [
        for (final company in sorted)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = company.id),
            onExit: (_) => setState(() => _hovered = null),
            child: Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => widget.onOpen(company),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _hovered == company.id ? JitanColors.tableHover : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
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
                            color: _hovered == null || _hovered == company.id ? JitanColors.ink : JitanColors.ink.withValues(alpha: 0.35),
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
                      SizedBox(
                        width: 22,
                        child: _hovered == company.id
                            ? const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

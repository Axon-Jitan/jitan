import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../l10n/admin_text_keys.dart';
import 'dashboard_text.dart';

/// The four totals, each opening its page.
class DashboardTiles extends StatelessWidget {
  const DashboardTiles({super.key, required this.dashboard});

  final Dashboard dashboard;

  static const _gap = 16.0;
  static const _fourAcrossFrom = 760.0;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile(
        label: context.t(AdminTextKeys.dashboardCompanies),
        value: DashboardText.number(dashboard.companies.length),
        note: context.t(AdminTextKeys.dashboardCompaniesNote),
        path: AdminRoutes.companies,
      ),
      _Tile(
        label: context.t(AdminTextKeys.dashboardEmployees),
        value: DashboardText.number(dashboard.employees),
        note: context.t(AdminTextKeys.dashboardEmployeesNote, args: {'count': DashboardText.number(dashboard.employeesSetUp)}),
        path: AdminRoutes.employees,
      ),
      _Tile(
        label: context.t(AdminTextKeys.dashboardLocations),
        value: DashboardText.number(dashboard.locations),
        note: context.t(AdminTextKeys.dashboardLocationsNote),
        path: AdminRoutes.locations,
      ),
      _Tile(
        label: context.t(AdminTextKeys.dashboardHours),
        value: DashboardText.hours(context, dashboard.registeredMinutes),
        note: context.t(AdminTextKeys.dashboardHoursNote, args: {'hours': DashboardText.hours(context, dashboard.plannedMinutes)}),
        path: AdminRoutes.reports,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final across = constraints.maxWidth >= _fourAcrossFrom ? 4 : 2;
        final gap = across == 2 ? 12.0 : _gap;
        final width = (constraints.maxWidth - gap * (across - 1)) / across;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final tile in tiles) SizedBox(width: width, child: tile)],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.note, required this.path});

  final String label;
  final String value;
  final String note;
  final String path;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(JitanDimensions.tableCardRadius);
    return Material(
      color: JitanColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        hoverColor: JitanColors.tableHover,
        onTap: () => context.go(path),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: JitanTextStyles.pageTitle),
                    ),
                    const SizedBox(height: 2),
                    Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell.copyWith(fontSize: 12, color: JitanColors.inkMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

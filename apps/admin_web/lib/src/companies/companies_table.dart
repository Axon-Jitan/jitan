import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/relative_date_text.dart';
import '../l10n/admin_text_keys.dart';

/// The companies table from Figma `Admin / Companies` (`153:61`), as a
/// [JitanSliverTable] (pinned heading, rows built as they come into view).
///
/// "Locations" has no data source yet (ERD GAP-03: no company → address
/// relationship) and shows an explicit placeholder rather than a number.
class CompaniesTable extends StatelessWidget {
  const CompaniesTable({super.key, required this.companies, required this.now});

  final List<CompanySummary> companies;

  /// Reference time for "Last updated"; injected for deterministic tests.
  final DateTime now;

  /// Column widths proportional to the Figma table (x = 20/360/520/700/860
  /// in a 1120 px card).
  static const _flexCompany = 340;
  static const _flexEmployees = 160;
  static const _flexLocations = 180;
  static const _flexStatus = 160;
  static const _flexLastUpdated = 240;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    return JitanSliverTable(
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.companyColumnName), flex: _flexCompany),
        JitanTableColumn(label: t.t(AdminTextKeys.companyColumnEmployees), flex: _flexEmployees),
        JitanTableColumn(label: t.t(AdminTextKeys.companyColumnLocations), flex: _flexLocations),
        JitanTableColumn(label: t.t(AdminTextKeys.companyColumnStatus), flex: _flexStatus),
        JitanTableColumn(label: t.t(AdminTextKeys.companyColumnLastUpdated), flex: _flexLastUpdated),
      ],
      rowCount: companies.length,
      cells: (i) => _cells(t, companies[i]),
    );
  }

  List<Widget> _cells(Translations t, CompanySummary company) => [
    Text(company.name, style: JitanTextStyles.tableCellStrong, overflow: TextOverflow.ellipsis),
    Text('${company.employeeCount}', style: JitanTextStyles.tableCell),
    Tooltip(
      message: t.t(AdminTextKeys.companyLocationsUnavailable),
      child: Text(t.t(CommonTextKeys.valueUnavailable), style: JitanTextStyles.tableCell),
    ),
    JitanStatusLabel(
      label: t.t(company.isActive ? CommonTextKeys.statusActive : CommonTextKeys.statusInactive),
      isPositive: company.isActive,
    ),
    Text(
      company.lastUpdatedAt == null
          ? t.t(CommonTextKeys.valueUnavailable)
          : relativeDateText(t, company.lastUpdatedAt!, now: now),
      style: JitanTextStyles.tableCell,
    ),
  ];
}

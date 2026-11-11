import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'company_text.dart';

/// The companies table (Figma `1524:2`): a row opens the company; its
/// employee count opens their Employees. An inactive company is greyed; the
/// one just added is lit up.
class CompaniesTable extends StatelessWidget {
  const CompaniesTable({
    super.key,
    required this.companies,
    required this.now,
    required this.onOpen,
    required this.onEmployees,
    this.fresh,
  });

  final List<CompanySummary> companies;

  /// Reference time for "Last updated"; injected for deterministic tests.
  final DateTime now;
  final ValueChanged<CompanySummary> onOpen;
  final ValueChanged<CompanySummary> onEmployees;

  /// The company just added.
  final int? fresh;

  /// Column widths proportional to Figma (380/200/200/260).
  static const _flexCompany = 380;
  static const _flexEmployees = 200;
  static const _flexStatus = 200;
  static const _flexLastUpdated = 260;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    return JitanSliverTable(
      onRowTap: (i) => onOpen(companies[i]),
      hoverChevron: true,
      rowColor: (i) => companies[i].id == fresh ? JitanColors.successSurface : null,
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.companyColumnName), flex: _flexCompany),
        JitanTableColumn(label: t.t(AdminTextKeys.companyColumnEmployees), flex: _flexEmployees),
        JitanTableColumn(label: t.t(AdminTextKeys.companyColumnStatus), flex: _flexStatus),
        JitanTableColumn(label: t.t(AdminTextKeys.companyColumnLastUpdated), flex: _flexLastUpdated),
      ],
      rowCount: companies.length,
      cells: (i) => _cells(context, companies[i]),
    );
  }

  List<Widget> _cells(BuildContext context, CompanySummary company) {
    final faded = !company.isActive;
    final ink = faded ? JitanColors.disabledText : JitanColors.ink;
    final updated = company.lastUpdatedAt;
    return [
      Text(company.name, style: JitanTextStyles.tableCellStrong.copyWith(color: ink), overflow: TextOverflow.ellipsis),
      Align(
        alignment: Alignment.centerLeft,
        child: company.employeeCount == 0
            ? Text('0', style: JitanTextStyles.tableCell.copyWith(color: ink))
            : Semantics(
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onEmployees(company),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Text('${company.employeeCount}', style: JitanTextStyles.tableCell.copyWith(color: ink)),
                        const Icon(Icons.arrow_forward, size: 14, color: JitanColors.inkMuted),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      JitanStatusLabel(
        label: context.t(company.isActive ? CommonTextKeys.statusActive : CommonTextKeys.statusInactive),
        isPositive: company.isActive,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: updated == null ? '' : CompanyText.updatedExactly(context, updated),
          waitDuration: const Duration(milliseconds: 300),
          child: Text(CompanyText.updated(context, company, now), style: JitanTextStyles.tableCell.copyWith(color: ink)),
        ),
      ),
    ];
  }
}

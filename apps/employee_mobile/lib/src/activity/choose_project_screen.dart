import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_widgets.dart';
import 'activity_text.dart';

/// Choose a project (Figma `1512:502`): every active project (D44), searched
/// by SAP number or name, the recently used ones first. Pops the chosen one.
class ChooseProjectScreen extends StatefulWidget {
  const ChooseProjectScreen({super.key, required this.projects, this.currentId});

  final List<MyProject> projects;

  /// The project they're on now: "Now" instead of a chevron.
  final int? currentId;

  @override
  State<ChooseProjectScreen> createState() => _ChooseProjectScreenState();
}

class _ChooseProjectScreenState extends State<ChooseProjectScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The SAP number is the start of the name, so one search finds both.
  List<MyProject> get _matching {
    final words = _search.text.trim().toLowerCase();
    if (words.isEmpty) return widget.projects;
    return [
      for (final project in widget.projects)
        if (project.name.toLowerCase().contains(words)) project,
    ];
  }

  Widget _section(String title, List<MyProject> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 26),
      TodayEyebrow(title),
      const SizedBox(height: 10),
      TodayCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, project) in rows.indexed) ...[
              if (i > 0) const Divider(height: 1, color: JitanColors.inputBorder),
              _ProjectRow(
                project: project,
                isCurrent: project.id == widget.currentId,
                onTap: () => Navigator.of(context).pop(project),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final matching = _matching;
    final recent = [
      for (final p in matching)
        if (p.isRecent) p,
    ];
    final others = [
      for (final p in matching)
        if (!p.isRecent) p,
    ];
    OutlineInputBorder border(Color color) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color));
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      appBar: AppBar(backgroundColor: JitanColors.warmWhite, elevation: 0, scrolledUnderElevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Semantics(
              header: true,
              child: Text(context.t(EmployeeTextKeys.activityChooseProject), style: JitanMobileTextStyles.title),
            ),
            const SizedBox(height: 6),
            Text(context.t(EmployeeTextKeys.activityChooseProjectText), style: JitanMobileTextStyles.body),
            const SizedBox(height: 22),
            if (widget.projects.isEmpty)
              Text(context.t(EmployeeTextKeys.activityNoProjects), style: JitanMobileTextStyles.body)
            else ...[
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: JitanMobileTextStyles.body.copyWith(color: JitanColors.ink),
                decoration: InputDecoration(
                  hintText: context.t(EmployeeTextKeys.activitySearchProjects),
                  hintStyle: JitanMobileTextStyles.body,
                  prefixIcon: const Icon(Icons.search, size: 18, color: JitanColors.inkMuted),
                  filled: true,
                  fillColor: JitanColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: border(JitanColors.inputBorder),
                  focusedBorder: border(JitanColors.ink),
                ),
              ),
              if (matching.isEmpty) ...[
                const SizedBox(height: 26),
                Text(context.t(EmployeeTextKeys.activityNoMatch), style: JitanMobileTextStyles.body),
              ],
              if (recent.isNotEmpty) _section(context.t(EmployeeTextKeys.activityRecent), recent),
              if (others.isNotEmpty) _section(context.t(EmployeeTextKeys.activityAllProjects), others),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.isCurrent, required this.onTap});

  final MyProject project;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: JitanMobileTextStyles.cardTitle),
                const SizedBox(height: 3),
                Text(ActivityText.project(context, project), style: JitanMobileTextStyles.cardText),
              ],
            ),
          ),
          if (isCurrent)
            Text(
              context.t(EmployeeTextKeys.activityNow),
              style: JitanMobileTextStyles.cardText.copyWith(color: JitanColors.success, fontWeight: FontWeight.w600),
            )
          else
            const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
        ],
      ),
    ),
  );
}

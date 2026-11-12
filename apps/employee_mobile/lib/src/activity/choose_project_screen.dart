import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/phone_widgets.dart';
import 'activity_text.dart';

/// Choose a project (Figma `1588:2`): every active project (D44), searched
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
      const SizedBox(height: 24),
      Text(title, style: JitanMobileTextStyles.label),
      const SizedBox(height: 8),
      PhoneListCard(
        padding: EdgeInsets.zero,
        children: [
          for (final project in rows)
            PhoneListRow(
              title: project.name,
              detail: ActivityText.project(context, project),
              trailing: project.id == widget.currentId
                  ? Text(
                      context.t(EmployeeTextKeys.activityNow),
                      style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 13, color: JitanColors.success),
                    )
                  : const PhoneChevron(),
              onTap: () => Navigator.of(context).pop(project),
            ),
        ],
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
      appBar: phoneAppBar(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Semantics(
              header: true,
              child: Text(context.t(EmployeeTextKeys.activityChooseProject), style: JitanMobileTextStyles.pageTitle),
            ),
            const SizedBox(height: 6),
            Text(context.t(EmployeeTextKeys.activityChooseProjectText), style: JitanMobileTextStyles.pageSubtitle),
            const SizedBox(height: 24),
            if (widget.projects.isEmpty)
              Text(context.t(EmployeeTextKeys.activityNoProjects), style: JitanMobileTextStyles.pageSubtitle)
            else ...[
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: JitanMobileTextStyles.rowText,
                cursorColor: JitanColors.ink,
                decoration: InputDecoration(
                  hintText: context.t(EmployeeTextKeys.activitySearchProjects),
                  hintStyle: JitanMobileTextStyles.rowText.copyWith(color: JitanColors.inkMuted),
                  prefixIcon: const Icon(Icons.search, size: 20, color: JitanColors.inkMuted),
                  filled: true,
                  fillColor: JitanColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: border(JitanColors.inputBorder),
                  focusedBorder: border(JitanColors.ink),
                ),
              ),
              if (matching.isEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  context.t(EmployeeTextKeys.activityNoMatch, args: {'search': _search.text.trim()}),
                  style: JitanMobileTextStyles.pageSubtitle,
                ),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/web_session.dart';
import '../l10n/employee_web_text_keys.dart';
import 'web_router.dart';

/// Sidebar and page frame around every page (Figma `1499:19`); a menu on a
/// phone. The name lives here only, not at the top of each page.
class WebShell extends StatelessWidget {
  const WebShell({super.key, required this.location, required this.session, required this.child});

  final String location;
  final WebSession session;
  final Widget child;

  @override
  Widget build(BuildContext context) => JitanWebShell(
    sidebar: JitanWebSidebar(
      selectedPath: location,
      footer: _user(context),
      onNavigate: (path) {
        Scaffold.maybeOf(context)?.closeDrawer();
        context.go(path);
      },
      destinations: [
        JitanNavDestination(label: context.t(EmployeeWebTextKeys.navHome), path: WebRoutes.home),
        JitanNavDestination(label: context.t(EmployeeWebTextKeys.navPeriod), path: WebRoutes.period),
        JitanNavDestination(label: context.t(EmployeeWebTextKeys.navProjects), path: WebRoutes.projects),
        JitanNavDestination(label: context.t(EmployeeWebTextKeys.navProfile), path: WebRoutes.profile),
      ],
    ),
    child: child,
  );

  Widget _user(BuildContext context) {
    final account = session.account;
    final name = [account?.firstName, account?.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty) Text(name, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13, color: JitanColors.surface)),
          if (account != null) ...[
            const SizedBox(height: 2),
            Text(account.code, style: JitanTextStyles.sidebarCaption),
          ],
        ],
      ),
    );
  }
}

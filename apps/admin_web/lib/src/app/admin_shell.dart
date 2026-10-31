import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/admin_session.dart';
import '../l10n/admin_text_keys.dart';
import 'admin_routes.dart';

/// Sidebar + page frame around every HR/Admin page.
///
/// The sidebar lists only implemented pages. Figma's other items (Terminals,
/// Exceptions, …) are added with their slices.
/// The role caption (Figma "ADMIN"/"HR") is omitted until the signed-in
/// user's credential group is available from the API; it is never hardcoded.
///
/// With dev tools enabled, the development company selector sits above every
/// page (until the final company switcher is designed).
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.location,
    required this.child,
    required this.companiesApi,
    required this.session,
  });

  /// Current route path, for highlighting the active item.
  final String location;
  final Widget child;
  final CompaniesApi companiesApi;
  final AdminSession session;

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
        JitanNavDestination(label: context.t(AdminTextKeys.navDashboard), path: AdminRoutes.dashboard),
        JitanNavDestination(label: context.t(AdminTextKeys.navCompanies), path: AdminRoutes.companies),
        JitanNavDestination(label: context.t(AdminTextKeys.navEmployees), path: AdminRoutes.employees),
        JitanNavDestination(label: context.t(AdminTextKeys.navLocations), path: AdminRoutes.locations),
        JitanNavDestination(label: context.t(AdminTextKeys.navSchedules), path: AdminRoutes.schedules),
        JitanNavDestination(label: context.t(AdminTextKeys.navGroups), path: AdminRoutes.groups),
        JitanNavDestination(label: context.t(AdminTextKeys.navProjects), path: AdminRoutes.projects),
        JitanNavDestination(label: context.t(AdminTextKeys.navTimeRecords), path: AdminRoutes.timeRecords),
        JitanNavDestination(label: context.t(AdminTextKeys.navReports), path: AdminRoutes.reports),
      ],
    ),
    child: child,
  );

  /// Figma `1469:53`: who is signed in, and the way out.
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
            const SizedBox(height: 6),
          ],
          TextButton(
            onPressed: session.signOut,
            style: TextButton.styleFrom(foregroundColor: JitanColors.sidebarText, padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
            child: Text(context.t(AdminTextKeys.signOut)),
          ),
        ],
      ),
    );
  }
}

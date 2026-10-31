import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'admin_routes.dart';

/// Sidebar + page frame around every HR/Admin page.
///
/// The sidebar lists only implemented pages. Figma's other items (Dashboard,
/// Terminals, Time records, Exceptions, Reports) are added with their slices.
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
  });

  /// Current route path, for highlighting the active item.
  final String location;
  final Widget child;
  final CompaniesApi companiesApi;

  @override
  Widget build(BuildContext context) => JitanWebShell(
    sidebar: JitanWebSidebar(
      selectedPath: location,
      onNavigate: (path) {
        Scaffold.maybeOf(context)?.closeDrawer();
        context.go(path);
      },
      destinations: [
        JitanNavDestination(label: context.t(AdminTextKeys.navCompanies), path: AdminRoutes.companies),
        JitanNavDestination(label: context.t(AdminTextKeys.navEmployees), path: AdminRoutes.employees),
        JitanNavDestination(label: context.t(AdminTextKeys.navLocations), path: AdminRoutes.locations),
        JitanNavDestination(label: context.t(AdminTextKeys.navSchedules), path: AdminRoutes.schedules),
        JitanNavDestination(label: context.t(AdminTextKeys.navGroups), path: AdminRoutes.groups),
        JitanNavDestination(label: context.t(AdminTextKeys.navTimeRecords), path: AdminRoutes.timeRecords),
        JitanNavDestination(label: context.t(AdminTextKeys.navReports), path: AdminRoutes.reports),
      ],
    ),
    child: child,
  );
}

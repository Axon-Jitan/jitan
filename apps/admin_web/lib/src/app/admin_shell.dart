import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_strings.dart';
import 'admin_routes.dart';

/// Sidebar + page frame around every HR/Admin page.
///
/// The sidebar lists only implemented pages. Figma's other items (Dashboard,
/// Employees, Terminals, Time records, Exceptions, Reports) are added with
/// their slices. The role caption (Figma "ADMIN"/"HR") is omitted until the
/// signed-in user's credential group is available from the API; it is never
/// hardcoded.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.location, required this.child});

  /// Current route path, for highlighting the active item.
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) => JitanWebShell(
        sidebar: JitanWebSidebar(
          selectedPath: location,
          onNavigate: (path) {
            Scaffold.maybeOf(context)?.closeDrawer();
            context.go(path);
          },
          destinations: [
            JitanNavDestination(label: AdminStrings.companiesNav, path: AdminRoutes.companies),
          ],
        ),
        child: child,
      );
}

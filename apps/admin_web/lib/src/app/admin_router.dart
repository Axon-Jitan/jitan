import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/admin_session.dart';
import '../auth/no_access_screen.dart';
import '../auth/sign_in_screen.dart';
import '../auth/platform/session_store.dart';
import '../companies/companies_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../employees/employees_screen.dart';
import '../employees/import/employee_import_screen.dart';
import '../groups/group_page.dart';
import '../groups/groups_screen.dart';
import '../locations/locations_screen.dart';
import '../reports/reports_screen.dart';
import '../schedules/schedules_screen.dart';
import '../time_records/time_records_screen.dart';
import 'admin_routes.dart';
import 'admin_services.dart';
import 'admin_shell.dart';

/// Nothing opens without a session. The page asked for travels along in
/// `from`, so a link or a reload lands on it after sign-in.
String? _redirect(AdminSession session, GoRouterState state) {
  const gates = {AdminRoutes.checking, AdminRoutes.signIn, AdminRoutes.noAccess};
  final path = state.matchedLocation;
  final from = gates.contains(path) ? state.uri.queryParameters['from'] : state.uri.toString();
  String gate(String route) {
    if (path == route) return route;
    return from == null ? route : Uri(path: route, queryParameters: {'from': from}).toString();
  }

  return switch (session.status) {
    AdminSessionStatus.checking when path != AdminRoutes.checking => gate(AdminRoutes.checking),
    AdminSessionStatus.signedOut when path != AdminRoutes.signIn => gate(AdminRoutes.signIn),
    AdminSessionStatus.noAccess when path != AdminRoutes.noAccess => gate(AdminRoutes.noAccess),
    AdminSessionStatus.signedIn when gates.contains(path) || path == '/' =>
      from != null && from.startsWith('/') && from != '/' ? from : AdminRoutes.dashboard,
    _ => null,
  };
}

/// URL routing for the HR/Admin app. Unknown paths go to the Dashboard.
GoRouter buildAdminRouter({required AdminServices services, String? initialLocation}) {
  AdminShell shell(String location, Widget child) =>
      AdminShell(location: location, companiesApi: services.companiesApi, session: services.session, child: child);

  Widget dashboard() => DashboardScreen(api: services.dashboardApi, store: browserSessionStore());

  return GoRouter(
    initialLocation: initialLocation ?? AdminRoutes.dashboard,
    refreshListenable: services.session,
    redirect: (context, state) => _redirect(services.session, state),
    errorBuilder: (context, state) => shell(AdminRoutes.dashboard, dashboard()),
    routes: [
      GoRoute(
        path: AdminRoutes.checking,
        builder: (context, state) => const ColoredBox(color: JitanColors.warmWhite),
      ),
      GoRoute(
        path: AdminRoutes.signIn,
        builder: (context, state) => SignInScreen(session: services.session),
      ),
      GoRoute(
        path: AdminRoutes.noAccess,
        builder: (context, state) => NoAccessScreen(session: services.session),
      ),
      ShellRoute(
        builder: (context, state, child) => shell(state.matchedLocation, child),
        routes: [
          GoRoute(
            path: AdminRoutes.dashboard,
            pageBuilder: (context, state) => NoTransitionPage(child: dashboard()),
          ),
          GoRoute(
            path: AdminRoutes.companies,
            pageBuilder: (context, state) => NoTransitionPage(child: CompaniesScreen(api: services.companiesApi)),
          ),
          GoRoute(
            path: AdminRoutes.employees,
            pageBuilder: (context, state) => NoTransitionPage(
              child: EmployeesScreen(
                api: services.employeesApi,
                groupsApi: services.groupsApi,
                companiesApi: services.companiesApi,
                schedulesApi: services.schedulesApi,
              ),
            ),
            routes: [
              GoRoute(
                path: 'import',
                pageBuilder: (context, state) =>
                    NoTransitionPage(
                  child: EmployeeImportScreen(api: services.employeesApi, companiesApi: services.companiesApi),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AdminRoutes.timeRecords,
            pageBuilder: (context, state) => NoTransitionPage(
              child: TimeRecordsScreen(api: services.timeRecordsApi, companiesApi: services.companiesApi),
            ),
          ),
          GoRoute(
            path: AdminRoutes.reports,
            pageBuilder: (context, state) => NoTransitionPage(
              child: ReportsScreen(api: services.reportsApi, companiesApi: services.companiesApi),
            ),
          ),
          GoRoute(
            path: AdminRoutes.locations,
            pageBuilder: (context, state) => NoTransitionPage(
              child: LocationsScreen(api: services.locationsApi, maps: services.locationMaps),
            ),
          ),
          GoRoute(
            path: AdminRoutes.schedules,
            pageBuilder: (context, state) => NoTransitionPage(child: SchedulesScreen(api: services.schedulesApi)),
          ),
          GoRoute(
            path: AdminRoutes.groups,
            pageBuilder: (context, state) => NoTransitionPage(
              child: GroupsScreen(
                groupsApi: services.groupManagementApi,
                membersApi: services.groupMembersApi,
                schedulesApi: services.schedulesApi,
              ),
            ),
            routes: [
              GoRoute(
                path: ':groupId',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['groupId'] ?? '') ?? 0;
                  return NoTransitionPage(
                    key: ValueKey('group-$id'),
                    child: GroupPage(
                      key: ValueKey(id),
                      groupId: id,
                      groupsApi: services.groupManagementApi,
                      membersApi: services.groupMembersApi,
                      schedulesApi: services.schedulesApi,
                      scheduleSourceApi: services.scheduleSourceApi,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

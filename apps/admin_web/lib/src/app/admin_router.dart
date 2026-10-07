import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../companies/companies_screen.dart';
import '../employees/employees_screen.dart';
import 'admin_routes.dart';
import 'admin_services.dart';
import 'admin_shell.dart';

/// URL routing for the HR/Admin app. Unknown paths go to Companies.
GoRouter buildAdminRouter({required AdminServices services, String? initialLocation}) {
  AdminShell shell(String location, Widget child) =>
      AdminShell(location: location, companiesApi: services.companiesApi, devTools: services.devTools, child: child);

  return GoRouter(
    initialLocation: initialLocation ?? AdminRoutes.companies,
    redirect: (context, state) => state.matchedLocation == '/' ? AdminRoutes.companies : null,
    errorBuilder: (context, state) => shell(AdminRoutes.companies, CompaniesScreen(api: services.companiesApi)),
    routes: [
      ShellRoute(
        builder: (context, state, child) => shell(state.matchedLocation, child),
        routes: [
          GoRoute(
            path: AdminRoutes.companies,
            pageBuilder: (context, state) => NoTransitionPage(child: CompaniesScreen(api: services.companiesApi)),
          ),
          GoRoute(
            path: AdminRoutes.employees,
            pageBuilder: (context, state) => NoTransitionPage(
              child: EmployeesScreen(api: services.employeesApi, groupsApi: services.groupsApi),
            ),
          ),
        ],
      ),
    ],
  );
}

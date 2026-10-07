import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';

import '../companies/companies_screen.dart';
import 'admin_routes.dart';
import 'admin_shell.dart';

/// URL routing for the HR/Admin app. Unknown paths go to Companies, the
/// only page built so far.
GoRouter buildAdminRouter({required CompaniesApi companiesApi, String? initialLocation}) => GoRouter(
      initialLocation: initialLocation ?? AdminRoutes.companies,
      redirect: (context, state) =>
          state.matchedLocation == '/' ? AdminRoutes.companies : null,
      errorBuilder: (context, state) =>
          AdminShell(location: AdminRoutes.companies, child: CompaniesScreen(api: companiesApi)),
      routes: [
        ShellRoute(
          builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(
              path: AdminRoutes.companies,
              pageBuilder: (context, state) =>
                  NoTransitionPage(child: CompaniesScreen(api: companiesApi)),
            ),
          ],
        ),
      ],
    );

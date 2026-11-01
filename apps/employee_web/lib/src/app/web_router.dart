import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/sign_in_screen.dart';
import '../auth/web_session.dart';
import '../home/home_screen.dart';
import '../period/period_screen.dart';
import '../profile/profile_screen.dart';
import '../projects/projects_screen.dart';
import 'web_services.dart';
import 'web_shell.dart';

abstract final class WebRoutes {
  static const checking = '/checking';
  static const signIn = '/sign-in';
  static const home = '/home';
  static const period = '/period';
  static const projects = '/projects';
  static const profile = '/profile';
}

/// Nothing opens without a session. The page asked for travels along in
/// `from`, so a link or a reload lands on it after sign-in.
String? _redirect(WebSession session, GoRouterState state) {
  const gates = {WebRoutes.checking, WebRoutes.signIn};
  final path = state.matchedLocation;
  final from = gates.contains(path) ? state.uri.queryParameters['from'] : state.uri.toString();
  String gate(String route) {
    if (path == route) return route;
    return from == null ? route : Uri(path: route, queryParameters: {'from': from}).toString();
  }

  return switch (session.status) {
    WebSessionStatus.checking when path != WebRoutes.checking => gate(WebRoutes.checking),
    WebSessionStatus.signedOut when path != WebRoutes.signIn => gate(WebRoutes.signIn),
    WebSessionStatus.signedIn when gates.contains(path) || path == '/' =>
      from != null && from.startsWith('/') && from != '/' ? from : WebRoutes.home,
    _ => null,
  };
}

/// URL routing. Unknown paths go Home.
GoRouter buildWebRouter({
  required WebServices services,
  required VoidCallback onLanguageChanged,
  DateTime Function()? clock,
  String? initialLocation,
}) {
  Page<void> page(String location, Widget child) =>
      NoTransitionPage(child: WebShell(location: location, session: services.session, child: child));

  Widget home() => HomeScreen(services: services, clock: clock);

  return GoRouter(
    initialLocation: initialLocation ?? WebRoutes.home,
    refreshListenable: services.session,
    redirect: (context, state) => _redirect(services.session, state),
    errorBuilder: (context, state) => WebShell(location: WebRoutes.home, session: services.session, child: home()),
    routes: [
      GoRoute(path: WebRoutes.checking, builder: (context, state) => const ColoredBox(color: JitanColors.warmWhite)),
      GoRoute(path: WebRoutes.signIn, builder: (context, state) => SignInScreen(session: services.session)),
      GoRoute(path: WebRoutes.home, pageBuilder: (context, state) => page(WebRoutes.home, home())),
      GoRoute(
        path: WebRoutes.period,
        pageBuilder: (context, state) => page(WebRoutes.period, PeriodScreen(services: services, clock: clock)),
      ),
      GoRoute(
        path: WebRoutes.projects,
        pageBuilder: (context, state) => page(WebRoutes.projects, ProjectsScreen(services: services)),
      ),
      GoRoute(
        path: WebRoutes.profile,
        pageBuilder: (context, state) =>
            page(WebRoutes.profile, ProfileScreen(services: services, onLanguageChanged: onLanguageChanged)),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../company_context/current_company.dart';
import '../l10n/admin_text_keys.dart';
import 'admin_router.dart';
import 'admin_services.dart';

/// Root widget of the HR/Admin app once translations are available. Must be
/// below a [TranslationScope] (see `AdminBootstrap`).
class AdminApp extends StatefulWidget {
  const AdminApp({super.key, required this.services, this.initialLocation, this.currentCompany});

  final AdminServices services;
  final String? initialLocation;

  /// Injected in tests; the app owns one otherwise.
  final CurrentCompanyController? currentCompany;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final GoRouter _router = buildAdminRouter(services: widget.services, initialLocation: widget.initialLocation);
  late final CurrentCompanyController _currentCompany = widget.currentCompany ?? CurrentCompanyController();

  @override
  void dispose() {
    _router.dispose();
    if (widget.currentCompany == null) _currentCompany.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CurrentCompanyScope(
    controller: _currentCompany,
    child: MaterialApp.router(
      title: context.t(AdminTextKeys.appTitle),
      theme: JitanTheme.web(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

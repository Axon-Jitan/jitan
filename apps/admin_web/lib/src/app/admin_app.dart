import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'admin_router.dart';

/// Root widget of the HR/Admin app once translations are loaded. Must be
/// below a [TranslationScope] (see `AdminBootstrap`).
class AdminApp extends StatefulWidget {
  const AdminApp({super.key, required this.companiesApi, this.initialLocation});

  final CompaniesApi companiesApi;
  final String? initialLocation;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final GoRouter _router = buildAdminRouter(
    companiesApi: widget.companiesApi,
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: context.t(AdminTextKeys.appTitle),
        theme: JitanTheme.light(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      );
}

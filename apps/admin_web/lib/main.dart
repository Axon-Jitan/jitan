import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'src/app/admin_app.dart';
import 'src/app/configuration_error_app.dart';
import 'src/config/admin_web_config.dart';

void main() {
  registerJitanFontLicenses();

  final config = AdminWebConfig.fromEnvironment();
  if (config == null) {
    runApp(const ConfigurationErrorApp());
    return;
  }

  final transport = ApiTransport(baseUri: config.apiBaseUri);
  runApp(AdminApp(companiesApi: CompaniesApi(transport)));
}

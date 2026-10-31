import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'src/app/admin_bootstrap.dart';
import 'src/app/admin_services.dart';
import 'src/app/configuration_error_app.dart';
import 'src/auth/admin_session.dart';
import 'src/auth/platform/session_store.dart';
import 'src/auth/session_http_client.dart';
import 'src/config/admin_web_config.dart';
import 'src/locations/location_map.dart';

void main() {
  registerJitanFontLicenses();

  final config = AdminWebConfig.fromEnvironment();
  if (config == null) {
    runApp(const ConfigurationErrorApp());
    return;
  }

  late final AdminSession session;
  final transport = ApiTransport(
    baseUri: config.apiBaseUri,
    httpClient: SessionHttpClient(() => session.sessionRefused()),
    accessToken: () => session.token,
  );
  session = AdminSession(
    auth: AuthApi(transport),
    me: MeApi(transport),
    companies: CompaniesApi(transport),
    store: browserSessionStore(),
  );
  runApp(
    AdminBootstrap(
      translationService: TranslationService(LanguagesApi(transport)),
      services: AdminServices(
        companiesApi: CompaniesApi(transport),
        employeesApi: EmployeesApi(transport),
        groupsApi: GroupsApi(transport),
        assignmentsApi: EmployeeAssignmentsApi(transport),
        schedulesApi: SchedulesApi(transport),
        groupManagementApi: GroupManagementApi(transport),
        groupMembersApi: GroupMembersApi(transport),
        timeRecordsApi: TimeRecordsApi(transport),
        scheduleSourceApi: ScheduleSourceApi(transport),
        locationsApi: LocationsApi(transport),
        reportsApi: ReportsApi(transport),
        dashboardApi: DashboardApi(transport),
        projectsApi: ProjectsApi(transport),
        session: session,
        locationMaps: switch (config.mapboxToken) {
          null => null,
          final token => LocationMaps.mapbox(token),
        },
      ),
    ),
  );
}

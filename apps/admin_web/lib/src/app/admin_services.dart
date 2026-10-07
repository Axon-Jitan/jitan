import 'package:jitan_api_client/jitan_api_client.dart';

/// The API clients and build options the HR/Admin pages need, passed down
/// from `main` in one value.
class AdminServices {
  const AdminServices({required this.companiesApi, required this.employeesApi, this.devTools = false});

  final CompaniesApi companiesApi;
  final EmployeesApi employeesApi;

  /// DEVELOPMENT ONLY tools in the UI (see `AdminWebConfig.devTools`).
  final bool devTools;
}

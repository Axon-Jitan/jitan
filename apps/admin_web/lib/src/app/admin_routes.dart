/// Route paths of the HR/Admin app. Only destinations that are built are
/// listed (ENGINEERING_RULES §31: no dead navigation).
abstract final class AdminRoutes {
  static const checking = '/checking';
  static const signIn = '/sign-in';
  static const noAccess = '/no-access';
  static const companies = '/companies';
  static const employees = '/employees';

  /// Import employees, opened from Employees.
  static const employeeImport = '$employees/import';
  static const locations = '/locations';
  static const schedules = '/schedules';
  static const groups = '/groups';
  static const timeRecords = '/time-records';
  static const reports = '/reports';

  /// One group's page.
  static String group(int id) => '$groups/$id';
}

/// Route paths of the HR/Admin app. Only destinations that are built are
/// listed (ENGINEERING_RULES §31: no dead navigation).
abstract final class AdminRoutes {
  static const checking = '/checking';
  static const signIn = '/sign-in';
  static const noAccess = '/no-access';
  static const dashboard = '/dashboard';
  static const companies = '/companies';
  static const employees = '/employees';

  /// Import employees, opened from Employees.
  static const employeeImport = '$employees/import';
  static const locations = '/locations';
  static const schedules = '/schedules';
  static const groups = '/groups';
  static const timeRecords = '/time-records';
  static const reports = '/reports';
  static const projects = '/projects';
  static const terminals = '/terminals';
  static const lists = '/lists';

  /// One group's page.
  static String group(int id) => '$groups/$id';

  /// Employees whose onboarding isn't done (from the Dashboard).
  static const employeesNotSetUp = '$employees?status=not_set_up';

  /// Time records of exact days, with a status filter or none (from the
  /// Dashboard).
  static String timeRecordsOf({String? status, required DateTime from, required DateTime to}) =>
      Uri(path: timeRecords, queryParameters: {'status': ?status, 'from': _date(from), 'to': _date(to)}).toString();

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Route paths of the HR/Admin app. Only destinations that are built are
/// listed (ENGINEERING_RULES §31: no dead navigation).
abstract final class AdminRoutes {
  static const companies = '/companies';
  static const employees = '/employees';
  static const schedules = '/schedules';
  static const groups = '/groups';

  /// One group's page.
  static String group(int id) => '$groups/$id';
}

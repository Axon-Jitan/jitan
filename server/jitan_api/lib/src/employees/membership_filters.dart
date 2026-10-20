/// SQL conditions for the employee links, which all have Active/MFD (IT
/// decision 2026-10-08, confirmed in IT's database 2026-10-09). A link counts
/// only while `Active = 1 AND MFD = 0`; a removed link keeps its row (soft
/// delete) and is hidden from normal reads.
abstract final class MembershipFilters {
  /// `tblUserCompany` row [alias] is a current membership.
  static String activeCompany(String alias) => '$alias.userCompanyActive = 1 AND $alias.userCompanyMFD = 0';

  /// `tblUserGroup` row [alias] is a current group assignment.
  static String activeGroup(String alias) => '$alias.userGroupActive = 1 AND $alias.userGroupMFD = 0';

  /// `tblUserCredGroup` row [alias] is a credential group the user holds.
  static String activeCredentialGroup(String alias) =>
      '$alias.userCredGroupActive = 1 AND $alias.userCredGroupMFD = 0';

  /// `tblUserSchedule` row [alias] is a schedule the user currently has.
  static String activeSchedule(String alias) => '$alias.userScheduleActive = 1 AND $alias.userScheduleMFD = 0';

  /// `tblUserLanguage` row [alias] is the user's current language.
  static String activeLanguage(String alias) => '$alias.userLanguageActive = 1 AND $alias.userLanguageMFD = 0';
}

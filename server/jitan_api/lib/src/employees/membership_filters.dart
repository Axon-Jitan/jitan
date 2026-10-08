/// SQL conditions for the employee links that have Active/MFD (IT decision
/// 2026-10-08). A link counts only while `Active = 1 AND MFD = 0`; a removed
/// link keeps its row (soft delete) and is hidden from normal reads. A NULL
/// flag (a row IT has not backfilled) counts as not active.
abstract final class MembershipFilters {
  /// `tblUserCompany` row [alias] is a current membership.
  static String activeCompany(String alias) => '$alias.userCompanyActive = 1 AND $alias.userCompanyMFD = 0';

  /// `tblUserGroup` row [alias] is a current group assignment.
  static String activeGroup(String alias) => '$alias.userGroupActive = 1 AND $alias.userGroupMFD = 0';
}

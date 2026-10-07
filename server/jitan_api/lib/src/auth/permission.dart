/// Actions an endpoint can require.
///
/// These are the server's **code-side** names. How each maps onto the ERD's
/// permission model (`tblCredGroup` → `tblAppModulesCredGroup` →
/// `tblAppModules`, plus `tblUserFunction` → `tblFunction`) is decided by the
/// production permission evaluator, pending CLARIFY-10 / CLARIFY-11. No
/// production role, module or function name is assumed here.
enum Permission {
  /// See the company list (HR/Admin "Companies" screen).
  viewCompanies,
}

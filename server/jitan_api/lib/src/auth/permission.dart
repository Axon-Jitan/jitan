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

  /// See one company's employees (company-scoped).
  viewEmployees,

  /// Create an employee in one company (company-scoped).
  createEmployee,

  /// Generate a temporary onboarding or recovery QR for an employee
  /// (company-scoped). The QR is a credential, so this is separate from
  /// [viewEmployees].
  issueTemporaryQr,

  /// See the assignable employee groups (e.g. Blue/White collar).
  viewGroups,

  /// "Reset account access" for an employee of one company (company-scoped):
  /// clears their password so they set up Jitan again with their QR.
  resetEmployeeAccess,

  /// "Manage employee assignments" (companies, groups, language, access)
  /// for an employee of one company (company-scoped). Adding an employee to
  /// another company also needs this permission in that company.
  manageEmployeeAssignments,

  /// Assign credential groups (`tblUserCredGroup`, access roles) to an
  /// employee. A credential group belongs to the user, not to one company,
  /// so it needs this permission in **every** company the employee belongs
  /// to. Separate from [manageEmployeeAssignments]: it changes access.
  manageEmployeeAccess,

  /// Read an employee's time registrations (`tblTimeReg`) as HR/Admin
  /// (company-scoped, through the employee's membership).
  viewTimeRegistrations,
}

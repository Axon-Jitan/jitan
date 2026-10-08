/// What happened, in code-side names.
///
/// Each value is linked to the `tblEventType` row whose `eventTypeName`
/// equals [typeName]. The real event type rows are pending CLARIFY-11; until
/// a matching row exists, the event is still logged, without a type link,
/// and a warning names the missing type.
enum AuditEventType {
  employeeCreated('employee.created'),

  /// A personal QR was stored for an employee who had none (e.g. created
  /// outside Jitan). Showing an existing QR is not audited as a change.
  personalQrGenerated('employee.personal_qr.generated'),

  /// The employee set their first password: onboarding is complete.
  onboardingCompleted('employee.onboarding.completed'),

  /// A signed-in employee replaced their password (Profile → Change
  /// password). Every other session of theirs ends.
  passwordChanged('employee.password.changed'),

  /// HR/Admin "Reset account access": the password was cleared, so the
  /// employee sets up Jitan again with their existing QR.
  accountAccessReset('employee.access.reset'),

  /// HR/Admin added the employee to a company (`tblUserCompany`).
  companyAssigned('employee.company.assigned'),

  /// HR/Admin assigned an employee group (`tblUserGroup`).
  groupAssigned('employee.group.assigned'),

  /// HR/Admin assigned a credential group (`tblUserCredGroup`).
  credentialGroupAssigned('employee.credential_group.assigned');

  const AuditEventType(this.typeName);

  final String typeName;
}

/// The `tblEventLog` foreign-key columns an event can reference. Enum values
/// carry the exact ERD column names, so no column name ever comes from input.
enum EventLogReference {
  user('userIDTarget'),
  company('companyID'),
  userCompany('userCompanyID'),
  group('groupID'),
  userGroup('userGroupID'),
  credGroup('credGroupID'),
  userCredGroup('userCredGroupID');

  const EventLogReference(this.column);

  final String column;
}

/// One audit event: who did it, what happened, and which records it touched.
class AuditEvent {
  const AuditEvent({required this.type, required this.actorUserId, required this.references});

  final AuditEventType type;

  /// `tblEventLog.userIDInit`.
  final int actorUserId;
  final Map<EventLogReference, int> references;
}

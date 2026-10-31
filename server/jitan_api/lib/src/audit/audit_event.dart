/// What happened, in code-side names.
///
/// Each value is linked to the `tblEventType` row whose `eventTypeName`
/// equals [typeName]. The real event type rows are pending CLARIFY-11; until
/// a matching row exists, the event is still logged, without a type link,
/// and a warning names the missing type.
enum AuditEventType {
  employeeCreated('employee.created'),

  /// HR/Admin removed the employee: `tblUser.userMFD = 1`, hidden from every
  /// list; nothing is deleted.
  employeeRemoved('employee.removed'),

  /// The employee registered a start or finish (the actual row; its rounded
  /// row is written in the same transaction).
  timeRegistered('time.registered'),

  /// The employee corrected a time; it waits for HR (D31).
  timeCorrectionRequested('time.correction.requested'),

  /// HR approved the employee's correction: it now counts (D31).
  timeCorrectionApproved('time.correction.approved'),

  /// HR rejected the employee's correction: it is switched off (D31).
  timeCorrectionRejected('time.correction.rejected'),

  /// HR corrected or added a start or finish (D7, D8).
  timeCorrected('time.corrected'),

  /// HR marked a day as non-work: its registrations are switched off.
  timeMarkedNonWork('time.marked_non_work'),

  /// HR/Admin generated a temporary onboarding QR (stored nowhere in MySQL;
  /// only the fact is logged).
  onboardingQrGenerated('employee.onboarding_qr.generated'),

  /// HR/Admin generated a temporary recovery QR after a reset.
  recoveryQrGenerated('employee.recovery_qr.generated'),

  /// The employee set their first password: onboarding is complete.
  onboardingCompleted('employee.onboarding.completed'),

  /// IT gave the very first person a password on a fresh database (AUTH-03).
  firstPasswordSet('employee.password.first_set'),

  /// A signed-in employee replaced their password (Profile → Change
  /// password). Every other session of theirs ends.
  passwordChanged('employee.password.changed'),

  /// HR/Admin "Reset account access": the password was cleared and every
  /// session ended; a temporary recovery QR lets the employee set a new one.
  accountAccessReset('employee.access.reset'),

  /// The employee set a new password with a temporary recovery QR.
  accessRecovered('employee.access.recovered'),

  /// HR/Admin added the employee to a company (`tblUserCompany`), or
  /// reactivated a removed membership.
  companyAssigned('employee.company.assigned'),

  /// HR/Admin removed the employee from a company (soft delete).
  companyRemoved('employee.company.removed'),

  /// HR/Admin assigned an employee group (`tblUserGroup`), or reactivated a
  /// removed one.
  groupAssigned('employee.group.assigned'),

  /// HR/Admin removed an employee group (soft delete).
  groupRemoved('employee.group.removed'),

  /// HR/Admin assigned a credential group (`tblUserCredGroup`).
  credentialGroupAssigned('employee.credential_group.assigned'),

  /// The preferred language changed (by the employee or HR/Admin). Generic:
  /// `tblEventLog` cannot say which language (GAP-12, accepted for V1).
  languageChanged('employee.language.changed'),

  /// HR/Admin added an employee group (`tblGroup`).
  groupCreated('group.created'),

  /// HR/Admin renamed an employee group.
  groupRenamed('group.renamed'),

  /// HR/Admin deactivated an employee group nobody is in any more.
  groupDeactivated('group.deactivated'),

  /// HR/Admin reactivated an employee group.
  groupReactivated('group.reactivated'),

  /// HR/Admin saved a group's work hours or breaks: one event per new
  /// `tblSchedule` row (with its type, day, group and rounding rule).
  scheduleCreated('schedule.created'),

  /// HR/Admin chose which of an employee's groups their schedule comes from
  /// ("Schedules come from").
  scheduleSourceChanged('employee.schedule_source.changed'),

  /// A schedule row no employee uses any more was switched off (soft
  /// delete), after a save or a removal by HR/Admin.
  scheduleDeactivated('schedule.deactivated'),

  /// HR/Admin added a location: its address, geofence and their link.
  locationCreated('location.created'),

  /// HR/Admin changed a location's name, address, pin or area.
  locationChanged('location.changed'),

  /// HR/Admin deactivated a location: Jitan stops recognising it.
  locationDeactivated('location.deactivated'),

  /// HR/Admin reactivated a location.
  locationReactivated('location.reactivated');

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
  userCredGroup('userCredGroupID'),
  schedule('scheduleID'),
  scheduleType('scheduleTypeID'),
  day('dayID'),
  roundingRule('roundingRuleID'),
  scheduleRoundingRule('scheduleRoundingRuleID'),
  timeReg('timeRegID'),
  timeRegType('timeRegTypeID'),
  address('addressID'),
  geofence('geofenceID'),
  geofenceAddress('geofenceAddressID'),

  /// PROPOSAL (ERD_GAPS GAP-15): exists only in the local database; written
  /// only with `JITAN_DEV_GROUP_SCHEDULES=true`.
  groupSchedule('groupScheduleID');

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

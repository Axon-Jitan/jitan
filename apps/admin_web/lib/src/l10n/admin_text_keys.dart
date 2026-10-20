/// `tblTranslation.translationUIName` keys used only by the HR/Admin app.
/// Shared keys are in `CommonTextKeys` (jitan_core).
///
/// Keys only. English texts live in `builtInEnglish` (jitan_core); other
/// languages in `tblTranslation` (I18N-01).
abstract final class AdminTextKeys {
  static const appTitle = 'app.admin.title';
  static const configErrorTitle = 'app.config.error.title';
  static const configErrorMessage = 'app.config.error.message';

  static const navCompanies = 'nav.companies';
  static const navEmployees = 'nav.employees';
  static const navSchedules = 'nav.schedules';

  static const devCompanySelectorLabel = 'dev.companySelector.label';
  static const devCompanySelectorPlaceholder = 'dev.companySelector.placeholder';
  static const devCompanySelectorLoadFailed = 'dev.companySelector.loadFailed';

  static const companyTitle = 'company.title';
  static const companyListSubtitle = 'company.list.subtitle';
  static const companySearch = 'company.search';
  static const companyListLoading = 'company.list.loading';
  static const companyColumnName = 'company.column.name';
  static const companyColumnEmployees = 'company.column.employees';
  static const companyColumnLocations = 'company.column.locations';
  static const companyColumnStatus = 'company.column.status';
  static const companyColumnLastUpdated = 'company.column.lastUpdated';
  static const companyLocationsUnavailable = 'company.locations.unavailable';
  static const companyEmptyTitle = 'company.empty.title';
  static const companyEmptyMessage = 'company.empty.message';
  static const companyNoMatchTitle = 'company.noMatch.title';

  /// Argument: `{search}`.
  static const companyNoMatchMessage = 'company.noMatch.message';

  static const employeeTitle = 'employee.title';
  static const employeeListSubtitle = 'employee.list.subtitle';
  static const employeeSearch = 'employee.search';
  static const employeeListLoading = 'employee.list.loading';
  static const employeeColumnName = 'employee.column.name';
  static const employeeColumnCode = 'employee.column.code';
  static const employeeColumnType = 'employee.column.type';
  static const employeeColumnLocation = 'employee.column.location';
  static const employeeColumnOnboarding = 'employee.column.onboarding';
  static const employeeColumnStatus = 'employee.column.status';
  static const employeeLocationUnavailable = 'employee.location.unavailable';
  static const employeeOnboardingActivated = 'employee.onboarding.activated';
  static const employeeOnboardingNotActivated = 'employee.onboarding.notActivated';
  static const employeeEmptyTitle = 'employee.empty.title';

  /// Argument: `{company}`.
  static const employeeEmptyMessage = 'employee.empty.message';
  static const employeeNoMatchTitle = 'employee.noMatch.title';

  /// Argument: `{search}`.
  static const employeeNoMatchMessage = 'employee.noMatch.message';
  static const employeeNoCompanyTitle = 'employee.noCompany.title';
  static const employeeNoCompanyMessage = 'employee.noCompany.message';

  static const employeeAddAction = 'employee.add.action';
  static const employeeAddTitle = 'employee.add.title';
  static const employeeAddSubtitle = 'employee.add.subtitle';
  static const employeeAddSubmit = 'employee.add.submit';

  /// Argument: `{name}`.
  static const employeeAddSuccess = 'employee.add.success';
  static const employeeFieldFirstName = 'employee.field.firstName';
  static const employeeFieldLastName = 'employee.field.lastName';
  static const employeeFieldCode = 'employee.field.code';
  static const employeeFieldType = 'employee.field.type';
  static const employeeFieldTypeNone = 'employee.field.type.none';
  static const employeeFieldTypeLoadFailed = 'employee.field.type.loadFailed';
  static const employeeFieldPhone = 'employee.field.phone';
  static const employeeFieldPhoneHint = 'employee.field.phone.hint';
  static const employeeFieldErrorRequired = 'employee.field.error.required';
  static const employeeFieldErrorDuplicateCode = 'employee.field.error.duplicateCode';
  static const employeeFieldErrorInvalidType = 'employee.field.error.invalidType';
  static const employeeFieldErrorTooLong = 'employee.field.error.tooLong';

  static const employeeDetailsTitle = 'employee.details.title';

  /// Arguments: `{company}`, `{code}`.
  static const employeeDetailsSubtitle = 'employee.details.subtitle';
  static const employeeDetailsLoading = 'employee.details.loading';
  static const employeeFieldLocation = 'employee.field.location';
  static const employeeFieldAccount = 'employee.field.account';
  static const employeeFieldStatus = 'employee.field.status';

  static const employeeOnboardingTitle = 'employee.onboarding.title';
  static const employeeOnboardingText = 'employee.onboarding.text';
  static const employeeOnboardingAction = 'employee.onboarding.action';
  static const employeeOnboardingCompletedText = 'employee.onboarding.completedText';

  /// Arguments: `{name}`, `{company}`.
  static const employeeQrSubtitle = 'employee.qr.subtitle';

  // Temporary QRs (Figma 153:1214, 207:111, 207:123)
  static const temporaryQrOnboardingTitle = 'employee.temporaryQr.onboarding.title';
  static const temporaryQrRecoveryTitle = 'employee.temporaryQr.recovery.title';
  static const temporaryQrRecoverySubtitle = 'employee.temporaryQr.recovery.subtitle';
  static const temporaryQrLoading = 'employee.temporaryQr.loading';

  /// Argument: `{minutes}`.
  static const temporaryQrValidStatus = 'employee.temporaryQr.status.valid';
  static const temporaryQrOnboardingInstruction = 'employee.temporaryQr.onboarding.instruction';

  /// Argument: `{time}` (mm:ss).
  static const temporaryQrExpiresIn = 'employee.temporaryQr.expiresIn';

  /// Argument: `{expiry}` ([temporaryQrExpiresIn]).
  static const temporaryQrOnboardingFacts = 'employee.temporaryQr.onboarding.facts';

  /// Argument: `{expiry}`.
  static const temporaryQrRecoveryFacts = 'employee.temporaryQr.recovery.facts';
  static const temporaryQrRecoveryNotTerminal = 'employee.temporaryQr.recovery.notTerminal';
  static const temporaryQrGenerateNew = 'employee.temporaryQr.generateNew';
  static const temporaryQrReplacementNote = 'employee.temporaryQr.replacementNote';
  static const temporaryQrClose = 'employee.temporaryQr.close';
  static const temporaryQrExpiredTitle = 'employee.temporaryQr.expired.title';
  static const temporaryQrExpiredText = 'employee.temporaryQr.expired.text';
  static const temporaryQrExpiredStatusTitle = 'employee.temporaryQr.expired.status.title';
  static const temporaryQrExpiredStatusText = 'employee.temporaryQr.expired.status.text';

  /// Argument: `{name}`.
  static const temporaryQrSemantics = 'employee.temporaryQr.semantics';

  static const employeeResetAccessAction = 'employee.resetAccess.action';
  static const employeeResetAccessTitle = 'employee.resetAccess.title';

  static const employeeResetAccessSubtitle = 'employee.resetAccess.subtitle';
  static const employeeResetAccessEffectsTitle = 'employee.resetAccess.effects.title';
  static const employeeResetAccessEffectSessions = 'employee.resetAccess.effects.sessions';
  static const employeeResetAccessEffectPassword = 'employee.resetAccess.effects.password';
  static const employeeResetAccessEffectRecovery = 'employee.resetAccess.effects.recovery';
  static const employeeResetAccessEffectQr = 'employee.resetAccess.effects.qr';
  static const employeeResetAccessNextStep = 'employee.resetAccess.nextStep';
  static const employeeResetAccessConfirm = 'employee.resetAccess.confirm';

  /// Argument: `{name}`.
  static const employeeResetAccessSuccess = 'employee.resetAccess.success';
  static const employeeResetAccessNotActivated = 'employee.resetAccess.notActivated';

  // Manage employee assignments (Figma Employees 04–07)
  static const assignmentsAction = 'employee.assignments.action';
  static const assignmentsTitle = 'employee.assignments.title';

  /// Arguments: `{name}`, `{company}`, `{code}`.
  static const assignmentsSubtitle = 'employee.assignments.subtitle';
  static const assignmentsLoading = 'employee.assignments.loading';
  static const assignmentsFooter = 'employee.assignments.footer';
  static const assignmentsSave = 'employee.assignments.save';
  static const assignmentsSaved = 'employee.assignments.saved';
  static const assignmentsTabCompanies = 'employee.assignments.tab.companies';
  static const assignmentsCompaniesTitle = 'employee.assignments.companies.title';
  static const assignmentsCompaniesText = 'employee.assignments.companies.text';
  static const assignmentsCompaniesCurrent = 'employee.assignments.companies.current';
  static const assignmentsCompaniesAdditional = 'employee.assignments.companies.additional';
  static const assignmentsCompaniesNoteTitle = 'employee.assignments.companies.note.title';
  static const assignmentsCompaniesNoteText = 'employee.assignments.companies.note.text';
  static const assignmentsTabGroups = 'employee.assignments.tab.groups';
  static const assignmentsGroupsTitle = 'employee.assignments.groups.title';
  static const assignmentsGroupsText = 'employee.assignments.groups.text';
  static const assignmentsGroupsAvailable = 'employee.assignments.groups.available';
  static const assignmentsGroupsHint = 'employee.assignments.groups.hint';
  static const assignmentsRemovable = 'employee.assignments.removable';

  // Remove Company / Group confirmation (Figma 207:329, 207:441)
  static const removeCompanyTitle = 'employee.assignments.remove.company.title';
  static const removeGroupTitle = 'employee.assignments.remove.group.title';
  static const removeAssignmentSubtitle = 'employee.assignments.remove.subtitle';
  static const removeAssignmentWhatHappens = 'employee.assignments.remove.whatHappens';
  static const removeCompanySoftDelete = 'employee.assignments.remove.company.softDelete';
  static const removeGroupSoftDelete = 'employee.assignments.remove.group.softDelete';
  static const removeAssignmentAudit = 'employee.assignments.remove.audit';
  static const removeAssignmentConfirm = 'employee.assignments.remove.confirm';
  static const assignmentsTabLanguage = 'employee.assignments.tab.language';
  static const assignmentsLanguageTitle = 'employee.assignments.language.title';
  static const assignmentsLanguageText = 'employee.assignments.language.text';
  static const assignmentsTabAccess = 'employee.assignments.tab.access';
  static const assignmentsAccessTitle = 'employee.assignments.access.title';
  static const assignmentsAccessText = 'employee.assignments.access.text';
  static const assignmentsAccessPicker = 'employee.assignments.access.picker';
  static const assignmentsAccessCurrent = 'employee.assignments.access.current';
  static const assignmentsAccessNone = 'employee.assignments.access.none';
  static const assignmentsAccessHint = 'employee.assignments.access.hint';
  static const employeeResetAccessAfterActivation = 'employee.resetAccess.afterActivation';

  // Schedules (Figma HR / Schedules 1317:2 to 1333:196)
  static const scheduleTitle = 'schedule.title';
  static const scheduleListSubtitle = 'schedule.list.subtitle';
  static const scheduleAddAction = 'schedule.add.action';
  static const scheduleSearchLabel = 'schedule.search.label';
  static const scheduleSearch = 'schedule.search';
  static const scheduleFilterType = 'schedule.filter.type';
  static const scheduleFilterTypeAll = 'schedule.filter.type.all';
  static const scheduleFilterGroup = 'schedule.filter.group';
  static const scheduleFilterGroupAll = 'schedule.filter.group.all';
  static const scheduleFilterStatus = 'schedule.filter.status';
  static const scheduleFilterStatusAll = 'schedule.filter.status.all';
  static const scheduleListHeading = 'schedule.list.heading';
  static const scheduleListLoading = 'schedule.list.loading';
  static const scheduleColumnName = 'schedule.column.name';
  static const scheduleColumnType = 'schedule.column.type';
  static const scheduleColumnGroup = 'schedule.column.group';
  static const scheduleColumnSetting = 'schedule.column.setting';
  static const scheduleColumnStatus = 'schedule.column.status';
  static const scheduleColumnActions = 'schedule.column.actions';
  static const scheduleKindWorkHours = 'schedule.kind.workHours';
  static const scheduleKindBreaks = 'schedule.kind.breaks';
  static const scheduleRowName = 'schedule.row.name';
  static const scheduleStatusDiffer = 'schedule.status.differ';
  static const scheduleSettingDiffer = 'schedule.setting.differ';
  static const scheduleEmptyTitle = 'schedule.empty.title';
  static const scheduleEmptyMessage = 'schedule.empty.message';
  static const scheduleNoMatchTitle = 'schedule.noMatch.title';
  static const scheduleNoMatchMessage = 'schedule.noMatch.message';
  static const scheduleActionsMenu = 'schedule.actions.menu';
  static const scheduleActionEdit = 'schedule.action.edit';
  static const scheduleActionDeactivate = 'schedule.action.deactivate';
  static const scheduleSaved = 'schedule.saved';
  static const scheduleDeactivated = 'schedule.deactivated';
  static const scheduleDayShort1 = 'schedule.day.short.1';
  static const scheduleDayShort2 = 'schedule.day.short.2';
  static const scheduleDayShort3 = 'schedule.day.short.3';
  static const scheduleDayShort4 = 'schedule.day.short.4';
  static const scheduleDayShort5 = 'schedule.day.short.5';
  static const scheduleDayShort6 = 'schedule.day.short.6';
  static const scheduleDayShort7 = 'schedule.day.short.7';
  static const scheduleSummaryDayRange = 'schedule.summary.dayRange';
  static const scheduleSummaryHours = 'schedule.summary.hours';
  static const scheduleSummaryBreak = 'schedule.summary.break';
  static const scheduleSummaryTolerance = 'schedule.summary.tolerance';
  static const scheduleSummaryToleranceSplit = 'schedule.summary.toleranceSplit';
  static const scheduleSummaryRounding = 'schedule.summary.rounding';
  static const scheduleRoundingNone = 'schedule.rounding.none';
  static const scheduleRoundingUp = 'schedule.rounding.up';
  static const scheduleRoundingDown = 'schedule.rounding.down';
  static const scheduleFormCreateTitle = 'schedule.form.create.title';
  static const scheduleFormEditTitle = 'schedule.form.edit.title';
  static const scheduleFormWorkHoursSubtitle = 'schedule.form.workHours.subtitle';
  static const scheduleFormBreaksSubtitle = 'schedule.form.breaks.subtitle';
  static const scheduleFormGroup = 'schedule.form.group';
  static const scheduleFormGroupHint = 'schedule.form.group.hint';
  static const scheduleFormType = 'schedule.form.type';
  static const scheduleFormDays = 'schedule.form.days';
  static const scheduleFormHours = 'schedule.form.hours';
  static const scheduleFormHoursByDay = 'schedule.form.hoursByDay';
  static const scheduleFormSameHours = 'schedule.form.sameHours';
  static const scheduleFormStart = 'schedule.form.start';
  static const scheduleFormFinish = 'schedule.form.finish';
  static const scheduleFormTolerance = 'schedule.form.tolerance';
  static const scheduleFormArrivalTolerance = 'schedule.form.arrivalTolerance';
  static const scheduleFormLeavingTolerance = 'schedule.form.leavingTolerance';
  static const scheduleFormToleranceHint = 'schedule.form.toleranceHint';
  static const scheduleFormRounding = 'schedule.form.rounding';
  static const scheduleFormStartRounding = 'schedule.form.startRounding';
  static const scheduleFormFinishRounding = 'schedule.form.finishRounding';
  static const scheduleFormUsualTime = 'schedule.form.usualTime';
  static const scheduleFormLength = 'schedule.form.length';
  static const scheduleFormLengthOption = 'schedule.form.lengthOption';
  static const scheduleFormBreakNoteTitle = 'schedule.form.breakNote.title';
  static const scheduleFormBreakNoteText = 'schedule.form.breakNote.text';
  static const scheduleFormFooter = 'schedule.form.footer';
  static const scheduleFormSave = 'schedule.form.save';
  static const scheduleFormOptionsLoading = 'schedule.form.options.loading';
  static const scheduleFormBlocked = 'schedule.form.blocked';
  static const scheduleFormDiffer = 'schedule.form.differ';
  static const scheduleFormConflictWorkHours = 'schedule.form.conflict.workHours';
  static const scheduleFormConflictBreaks = 'schedule.form.conflict.breaks';
  static const scheduleFormConflictAction = 'schedule.form.conflict.action';
  static const scheduleErrorNoDays = 'schedule.error.noDays';
  static const scheduleErrorFinishBeforeStart = 'schedule.error.finishBeforeStart';
  static const scheduleErrorTolerance = 'schedule.error.tolerance';
  static const scheduleErrorBreakOutside = 'schedule.error.breakOutside';
  static const scheduleErrorBreaksNeedHours = 'schedule.error.breaksNeedHours';
  static const scheduleErrorDays = 'schedule.error.days';
  static const scheduleDeactivateTitle = 'schedule.deactivate.title';
  static const scheduleDeactivateWorkHours = 'schedule.deactivate.workHours';
  static const scheduleDeactivateBreaks = 'schedule.deactivate.breaks';
  static const scheduleDeactivateKeep = 'schedule.deactivate.keep';
  static const scheduleDeactivateConfirm = 'schedule.deactivate.confirm';
}

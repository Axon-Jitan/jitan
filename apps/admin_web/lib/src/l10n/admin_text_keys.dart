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
  static const navGroups = 'nav.groups';
  static const navTimeRecords = 'nav.timeRecords';


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
  static const employeeColumnOnboarding = 'employee.column.onboarding';
  static const employeeColumnStatus = 'employee.column.status';
  static const employeeLocationUnavailable = 'employee.location.unavailable';
  static const employeeOnboardingActivated = 'employee.onboarding.activated';
  static const employeeOnboardingNotActivated = 'employee.onboarding.notActivated';
  static const employeeEmptyTitle = 'employee.empty.title';

  /// Argument: `{company}`.
  static const employeeEmptyMessage = 'employee.empty.message';
  static const employeeEmptyMessageAll = 'employee.empty.messageAll';

  /// Plural (`.one`/`.other`), Figma 1399:10 results footer.
  static const employeeResultsDisplayed = 'employee.results.displayed';

  /// Arguments: `{shown}`, `{total}`.
  static const employeeResultsShowing = 'employee.results.showing';
  static const employeeNoMatchTitle = 'employee.noMatch.title';

  /// Argument: `{search}`.
  static const employeeNoMatchMessage = 'employee.noMatch.message';
  static const employeeNoCompanyTitle = 'employee.noCompany.title';
  static const employeeNoCompanyMessage = 'employee.noCompany.message';

  // Import employees (Figma 1419:2 … 1419:404)
  static const employeeImportAction = 'employee.import.action';
  static const employeeImportBack = 'employee.import.back';
  static const employeeImportTitle = 'employee.import.title';
  static const employeeImportSubtitle = 'employee.import.subtitle';
  static const employeeImportCompany = 'employee.import.company';

  /// Argument: `{max}`.
  static const employeeImportDropHintNoCompany = 'employee.import.drop.hintNoCompany';
  static const employeeImportDropTitle = 'employee.import.drop.title';
  /// Argument: `{max}`.
  static const employeeImportDropHint = 'employee.import.drop.hint';
  static const employeeImportChoose = 'employee.import.choose';
  static const employeeImportChooseAnother = 'employee.import.chooseAnother';
  static const employeeImportReading = 'employee.import.reading';
  /// Argument: `{size}`.
  static const employeeImportFileKb = 'employee.import.file.kb';
  /// Argument: `{size}`.
  static const employeeImportFileMb = 'employee.import.file.mb';
  static const employeeImportColumnsTitle = 'employee.import.columns.title';
  static const employeeImportColumnsSubtitle = 'employee.import.columns.subtitle';
  static const employeeImportColumnRequired = 'employee.import.column.required';
  static const employeeImportColumnOptional = 'employee.import.column.optional';
  static const employeeImportColumnGroupsNote = 'employee.import.column.groupsNote';
  static const employeeImportColumnFirstName = 'employee.import.column.firstName';
  static const employeeImportColumnLastName = 'employee.import.column.lastName';
  static const employeeImportColumnCode = 'employee.import.column.code';
  static const employeeImportColumnPhone = 'employee.import.column.phone';
  static const employeeImportColumnEmail = 'employee.import.column.email';
  static const employeeImportColumnGroups = 'employee.import.column.groups';
  static const employeeImportTemplate = 'employee.import.template';
  static const employeeImportTemplateFile = 'employee.import.templateFile';
  static const employeeImportUnusableTitle = 'employee.import.unusable.title';
  static const employeeImportUnusableType = 'employee.import.unusable.type';
  static const employeeImportUnusableUnreadable = 'employee.import.unusable.unreadable';
  /// Argument: `{column}`.
  static const employeeImportUnusableMissingColumn = 'employee.import.unusable.missingColumn';
  static const employeeImportUnusableEmpty = 'employee.import.unusable.empty';
  /// Argument: `{count}`, `{max}`.
  static const employeeImportUnusableTooMany = 'employee.import.unusable.tooMany';
  /// Plural (`.one`/`.other`); the number is shown beside it.
  static const employeeImportSummaryRows = 'employee.import.summary.rows';
  static const employeeImportSummaryReady = 'employee.import.summary.ready';
  /// Plural; the number is shown beside it.
  static const employeeImportSummaryProblems = 'employee.import.summary.problems';
  /// Plural; argument `{size}`.
  static const employeeImportFileRows = 'employee.import.file.rows';
  static const employeeImportChange = 'employee.import.change';
  static const employeeImportTableRow = 'employee.import.table.row';
  static const employeeImportTableCode = 'employee.import.table.code';
  static const employeeImportTableStatus = 'employee.import.table.status';
  /// Argument: `{shown}`, `{total}`.
  static const employeeImportTableMore = 'employee.import.table.more';
  /// Argument: `{row}`.
  static const employeeImportRowLabel = 'employee.import.rowLabel';
  static const employeeImportReady = 'employee.import.ready';
  static const employeeImportProblemFirstNameMissing = 'employee.import.problem.firstNameMissing';
  static const employeeImportProblemLastNameMissing = 'employee.import.problem.lastNameMissing';
  static const employeeImportProblemCodeMissing = 'employee.import.problem.codeMissing';
  /// Argument: `{code}`.
  static const employeeImportProblemCodeUsed = 'employee.import.problem.codeUsed';
  /// Argument: `{row}`.
  static const employeeImportProblemCodeRepeated = 'employee.import.problem.codeRepeated';
  /// Argument: `{column}`.
  static const employeeImportProblemTooLong = 'employee.import.problem.tooLong';
  static const employeeImportProblemEmailInvalid = 'employee.import.problem.emailInvalid';
  /// Argument: `{group}`.
  static const employeeImportProblemGroupUnknown = 'employee.import.problem.groupUnknown';
  /// Argument: `{group}`.
  static const employeeImportProblemGroupAmbiguous = 'employee.import.problem.groupAmbiguous';
  static const employeeImportNote = 'employee.import.note';
  /// Plural.
  static const employeeImportSubmit = 'employee.import.submit';
  /// Plural.
  static const employeeImportImporting = 'employee.import.importing';
  /// Plural; argument `{company}`.
  static const employeeImportDoneTitle = 'employee.import.done.title';
  /// Plural.
  static const employeeImportDoneSkipped = 'employee.import.done.skipped';
  static const employeeImportDoneOnboarding = 'employee.import.done.onboarding';
  static const employeeImportDoneBack = 'employee.import.done.back';
  static const employeeImportDoneAgain = 'employee.import.done.again';

  // Remove employee (Figma 238:3689, 238:3853)
  static const employeeManageRemove = 'employee.manage.remove';
  static const employeeManageRemoveText = 'employee.manage.remove.text';
  static const employeeRemoveTitle = 'employee.remove.title';

  /// Argument: `{name}`.
  static const employeeRemoveQuestion = 'employee.remove.question';
  static const employeeRemoveEffect = 'employee.remove.effect';
  static const employeeRemoveConfirm = 'employee.remove.confirm';

  /// Argument: `{name}`.
  static const employeeRemoveSuccess = 'employee.remove.success';

  // Dates (Time records)
  static const dateMonthShort1 = 'date.month.short.1';
  static const dateMonthLong1 = 'date.month.long.1';
  static const dateMonthShort2 = 'date.month.short.2';
  static const dateMonthLong2 = 'date.month.long.2';
  static const dateMonthShort3 = 'date.month.short.3';
  static const dateMonthLong3 = 'date.month.long.3';
  static const dateMonthShort4 = 'date.month.short.4';
  static const dateMonthLong4 = 'date.month.long.4';
  static const dateMonthShort5 = 'date.month.short.5';
  static const dateMonthLong5 = 'date.month.long.5';
  static const dateMonthShort6 = 'date.month.short.6';
  static const dateMonthLong6 = 'date.month.long.6';
  static const dateMonthShort7 = 'date.month.short.7';
  static const dateMonthLong7 = 'date.month.long.7';
  static const dateMonthShort8 = 'date.month.short.8';
  static const dateMonthLong8 = 'date.month.long.8';
  static const dateMonthShort9 = 'date.month.short.9';
  static const dateMonthLong9 = 'date.month.long.9';
  static const dateMonthShort10 = 'date.month.short.10';
  static const dateMonthLong10 = 'date.month.long.10';
  static const dateMonthShort11 = 'date.month.short.11';
  static const dateMonthLong11 = 'date.month.long.11';
  static const dateMonthShort12 = 'date.month.short.12';
  static const dateMonthLong12 = 'date.month.long.12';
  static const dateWeekdayLong1 = 'date.weekday.long.1';
  static const dateWeekdayLong2 = 'date.weekday.long.2';
  static const dateWeekdayLong3 = 'date.weekday.long.3';
  static const dateWeekdayLong4 = 'date.weekday.long.4';
  static const dateWeekdayLong5 = 'date.weekday.long.5';
  static const dateWeekdayLong6 = 'date.weekday.long.6';
  static const dateWeekdayLong7 = 'date.weekday.long.7';
  static const monthShort = [dateMonthShort1, dateMonthShort2, dateMonthShort3, dateMonthShort4, dateMonthShort5, dateMonthShort6, dateMonthShort7, dateMonthShort8, dateMonthShort9, dateMonthShort10, dateMonthShort11, dateMonthShort12];
  static const monthLong = [dateMonthLong1, dateMonthLong2, dateMonthLong3, dateMonthLong4, dateMonthLong5, dateMonthLong6, dateMonthLong7, dateMonthLong8, dateMonthLong9, dateMonthLong10, dateMonthLong11, dateMonthLong12];
  static const weekdayLong = [dateWeekdayLong1, dateWeekdayLong2, dateWeekdayLong3, dateWeekdayLong4, dateWeekdayLong5, dateWeekdayLong6, dateWeekdayLong7];

  /// Arguments: `{weekday}`, `{day}`, `{month}` ("Tue 6 Oct").
  static const dateShort = 'date.short';

  /// Arguments: `{weekday}`, `{day}`, `{month}`, `{year}` ("Tuesday, 6 October 2026").
  static const dateLong = 'date.long';

  // Time records (Figma 160:2, 160:94)
  static const timeRecordsTitle = 'timeRecords.title';
  static const timeRecordsSubtitle = 'timeRecords.subtitle';
  static const timeRecordsFilterCompany = 'timeRecords.filter.company';
  static const timeRecordsFilterEmployee = 'timeRecords.filter.employee';
  static const timeRecordsFilterEmployeeHint = 'timeRecords.filter.employee.hint';
  static const timeRecordsFilterPeriod = 'timeRecords.filter.period';
  static const timeRecordsFilterStatus = 'timeRecords.filter.status';
  static const timeRecordsPeriodThisWeek = 'timeRecords.period.thisWeek';
  static const timeRecordsPeriodLastWeek = 'timeRecords.period.lastWeek';
  static const timeRecordsPeriodThisMonth = 'timeRecords.period.thisMonth';
  static const timeRecordsPeriodLastMonth = 'timeRecords.period.lastMonth';
  static const timeRecordsStatusAll = 'timeRecords.status.all';
  static const timeRecordsStatusComplete = 'timeRecords.status.complete';
  static const timeRecordsStatusWorking = 'timeRecords.status.working';
  static const timeRecordsStatusMissingFinish = 'timeRecords.status.missingFinish';
  static const timeRecordsStatusMissingStart = 'timeRecords.status.missingStart';
  static const timeRecordsResetAll = 'timeRecords.resetAll';
  static const timeRecordsSection = 'timeRecords.section';
  static const timeRecordsColumnEmployee = 'timeRecords.column.employee';
  static const timeRecordsColumnDate = 'timeRecords.column.date';
  static const timeRecordsColumnRounded = 'timeRecords.column.rounded';
  static const timeRecordsColumnActual = 'timeRecords.column.actual';
  static const timeRecordsColumnMethod = 'timeRecords.column.method';
  static const timeRecordsColumnStatus = 'timeRecords.column.status';
  static const timeRecordsColumnAction = 'timeRecords.column.action';
  static const timeRecordsMethodGeofence = 'timeRecords.method.geofence';
  static const timeRecordsMethodQr = 'timeRecords.method.qr';
  static const timeRecordsMethodManual = 'timeRecords.method.manual';
  static const timeRecordsView = 'timeRecords.view';
  static const timeRecordsLoading = 'timeRecords.loading';
  static const timeRecordsEmptyTitle = 'timeRecords.empty.title';
  static const timeRecordsEmptyMessage = 'timeRecords.empty.message';
  static const timeRecordsNoMatchTitle = 'timeRecords.noMatch.title';
  static const timeRecordsNoMatchMessage = 'timeRecords.noMatch.message';
  static const timeRecordDayTitle = 'timeRecord.day.title';
  static const timeRecordDaySubtitle = 'timeRecord.day.subtitle';
  static const timeRecordDayDetails = 'timeRecord.day.details';
  static const timeRecordDayStart = 'timeRecord.day.start';
  static const timeRecordDayFinish = 'timeRecord.day.finish';
  static const timeRecordDayActual = 'timeRecord.day.actual';
  static const timeRecordDayRounded = 'timeRecord.day.rounded';
  static const timeRecordDayNotRegistered = 'timeRecord.day.notRegistered';
  static const timeRecordDayCorrected = 'timeRecord.day.corrected';
  static const timeRecordDayEnteredAfterwards = 'timeRecord.day.enteredAfterwards';
  static const timeRecordDayNote = 'timeRecord.day.note';
  static const timeRecordDayClose = 'timeRecord.day.close';

  static const employeeAddAction = 'employee.add.action';
  static const employeeAddTitle = 'employee.add.title';
  static const employeeAddSubtitle = 'employee.add.subtitle';
  static const employeeColumnSchedule = 'employee.column.schedule';
  static const employeeColumnActions = 'employee.column.actions';
  static const employeeActionsMenu = 'employee.actions.menu';
  static const employeeFilterStatus = 'employee.filter.status';
  static const employeeFilterStatusAll = 'employee.filter.status.all';
  static const employeeFilterCompany = 'employee.filter.company';
  static const employeeFilterCompanyHint = 'employee.filter.company.hint';
  static const employeeFilterCompanyAll = 'employee.filter.company.all';
  static const employeeFilterCompanyFailed = 'employee.filter.company.failed';
  static const employeeSection = 'employee.section';
  static const employeeNoCompany = 'employee.noCompany';
  static const employeeNoMatch = 'employee.noMatch';
  static const employeeManageTitle = 'employee.manage.title';
  static const employeeManageQr = 'employee.manage.qr';
  static const employeeManageQrText = 'employee.manage.qr.text';
  static const employeeManageReset = 'employee.manage.reset';
  static const employeeManageResetText = 'employee.manage.reset.text';
  static const employeeAddSubtitleAssignments = 'employee.add.subtitle.assignments';
  static const employeeAddStepInformation = 'employee.add.step.information';
  static const employeeAddStepAssignments = 'employee.add.step.assignments';
  static const employeeAddStepActivation = 'employee.add.step.activation';
  static const employeeAddStepOf = 'employee.add.stepOf';
  static const employeeAddContinue = 'employee.add.continue';
  static const employeeAddSectionPersonal = 'employee.add.section.personal';
  static const employeeAddSectionContact = 'employee.add.section.contact';
  static const employeeAddSectionAssignments = 'employee.add.section.assignments';
  static const employeeFieldFirstNameHint = 'employee.field.firstName.hint';
  static const employeeFieldLastNameHint = 'employee.field.lastName.hint';
  static const employeeFieldCodeHint = 'employee.field.code.hint';
  static const employeeFieldEmail = 'employee.field.email';
  static const employeeFieldCompanies = 'employee.field.companies';
  static const employeeFieldCompaniesHint = 'employee.field.companies.hint';
  static const employeeFieldGroups = 'employee.field.groups';
  static const employeeFieldGroupsHint = 'employee.field.groups.hint';
  static const employeeFieldSchedule = 'employee.field.schedule';
  static const employeeFieldScheduleOption = 'employee.field.schedule.option';
  static const employeeFieldScheduleNone = 'employee.field.schedule.none';
  static const employeeFieldScheduleChoose = 'employee.field.schedule.choose';
  static const employeeFieldErrorEmail = 'employee.field.error.email';
  static const employeeFieldErrorUnavailable = 'employee.field.error.unavailable';
  static const employeeAddActivationTitle = 'employee.add.activation.title';
  static const employeeAddActivationSubtitle = 'employee.add.activation.subtitle';
  static const employeeAddActivationNotActivated = 'employee.add.activation.notActivated';
  static const employeeAddActivationEmployee = 'employee.add.activation.employee';
  static const employeeAddActivationStep1 = 'employee.add.activation.step1';
  static const employeeAddActivationStep2 = 'employee.add.activation.step2';
  static const employeeAddActivationStep3 = 'employee.add.activation.step3';
  static const employeeAddActivationScan = 'employee.add.activation.scan';
  static const employeeAddActivationScanHint = 'employee.add.activation.scanHint';
  static const employeeAddActivationNote = 'employee.add.activation.note';
  static const employeeAddActivationLoading = 'employee.add.activation.loading';
  static const employeeAddActivationFailed = 'employee.add.activation.failed';
  static const employeeAddFinish = 'employee.add.finish';
  static const employeeAddLoading = 'employee.add.loading';

  /// Argument: `{name}`.
  static const employeeAddSuccess = 'employee.add.success';
  static const employeeFieldFirstName = 'employee.field.firstName';
  static const employeeFieldLastName = 'employee.field.lastName';
  static const employeeFieldCode = 'employee.field.code';
  static const employeeFieldType = 'employee.field.type';
  static const employeeFieldPhone = 'employee.field.phone';
  static const employeeFieldPhoneHint = 'employee.field.phone.hint';
  static const employeeFieldErrorRequired = 'employee.field.error.required';
  static const employeeFieldErrorDuplicateCode = 'employee.field.error.duplicateCode';
  static const employeeFieldErrorTooLong = 'employee.field.error.tooLong';
  static const employeeFieldErrorPhoneLetters = 'employee.field.error.phoneLetters';
  static const employeeFieldErrorPhoneCountryCode = 'employee.field.error.phoneCountryCode';
  static const employeeFieldErrorPhoneInvalid = 'employee.field.error.phoneInvalid';
  static const employeeImportProblemPhoneCountryCode = 'employee.import.problem.phoneCountryCode';
  static const employeeImportProblemPhoneInvalid = 'employee.import.problem.phoneInvalid';

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
  static const scheduleFormGroup = 'schedule.form.group';
  static const scheduleFormGroupHint = 'schedule.form.group.hint';
  static const scheduleFormDays = 'schedule.form.days';
  static const scheduleFormSameHours = 'schedule.form.sameHours';
  static const scheduleFormStart = 'schedule.form.start';
  static const scheduleFormFinish = 'schedule.form.finish';
  static const scheduleFormArrivalTolerance = 'schedule.form.arrivalTolerance';
  static const scheduleFormLeavingTolerance = 'schedule.form.leavingTolerance';
  static const scheduleFormStartRounding = 'schedule.form.startRounding';
  static const scheduleFormFinishRounding = 'schedule.form.finishRounding';
  static const scheduleFormUsualTime = 'schedule.form.usualTime';
  static const scheduleFormLength = 'schedule.form.length';
  static const scheduleFormLengthOption = 'schedule.form.lengthOption';
  static const scheduleFormSave = 'schedule.form.save';
  static const scheduleFormOptionsLoading = 'schedule.form.options.loading';
  static const scheduleFormBlocked = 'schedule.form.blocked';
  static const scheduleFormDiffer = 'schedule.form.differ';
  static const scheduleFormConflictAction = 'schedule.form.conflict.action';
  static const scheduleErrorNoDays = 'schedule.error.noDays';
  static const scheduleErrorFinishBeforeStart = 'schedule.error.finishBeforeStart';
  static const scheduleErrorTolerance = 'schedule.error.tolerance';
  static const scheduleErrorBreakOutside = 'schedule.error.breakOutside';
  static const scheduleErrorDays = 'schedule.error.days';
  static const scheduleDeactivateTitle = 'schedule.deactivate.title';
  static const scheduleDeactivateWorkHours = 'schedule.deactivate.workHours';
  static const scheduleDeactivateBreaks = 'schedule.deactivate.breaks';
  static const scheduleDeactivateKeep = 'schedule.deactivate.keep';
  static const scheduleDeactivateConfirm = 'schedule.deactivate.confirm';
  static const scheduleFormWeekdays = 'schedule.form.weekdays';
  static const scheduleFormTimeHint = 'schedule.form.timeHint';
  static const scheduleFormMinutesUnit = 'schedule.form.minutesUnit';
  static const scheduleStepWorkingHours = 'schedule.step.workingHours';
  static const scheduleStepAttendance = 'schedule.step.attendance';
  static const scheduleStepReview = 'schedule.step.review';
  static const scheduleStepLabel = 'schedule.step.label';
  static const scheduleFormAppliesToGroup = 'schedule.form.appliesToGroup';
  static const scheduleFormDay = 'schedule.form.day';
  static const scheduleFormDailyNote = 'schedule.form.dailyNote';
  static const scheduleFormAttendanceNote = 'schedule.form.attendanceNote';
  static const scheduleColumnDaysHours = 'schedule.column.daysHours';
  static const scheduleManageTitle = 'schedule.manage.title';
  static const scheduleManageEdit = 'schedule.manage.edit';
  static const scheduleManageRemove = 'schedule.manage.remove';
  static const scheduleManageRemoveText = 'schedule.manage.remove.text';
  static const scheduleStepGroup = 'schedule.step.group';
  static const scheduleFormSubtitle = 'schedule.form.subtitle';
  static const scheduleFormConflict = 'schedule.form.conflict';
  static const scheduleBreakEveryDayText = 'schedule.break.everyDay.text';
  static const scheduleErrorBreakIncomplete = 'schedule.error.breakIncomplete';
  static const scheduleReviewTitle = 'schedule.review.title';
  static const scheduleReviewGroup = 'schedule.review.group';
  static const scheduleReviewHours = 'schedule.review.hours';
  static const scheduleReviewBreak = 'schedule.review.break';
  static const scheduleReviewAttendance = 'schedule.review.attendance';
  static const scheduleReviewRounding = 'schedule.review.rounding';
  static const scheduleReviewBreakValue = 'schedule.review.break.value';
  static const scheduleReviewAttendanceValue = 'schedule.review.attendance.value';
  static const scheduleReviewNote = 'schedule.review.note';
  static const scheduleManageEditWhole = 'schedule.manage.edit.whole';
  static const scheduleStepHoursBreak = 'schedule.step.hoursBreak';
  static const scheduleInfoGroup = 'schedule.info.group';
  static const scheduleInfoDays = 'schedule.info.days';
  static const scheduleInfoStart = 'schedule.info.start';
  static const scheduleInfoFinish = 'schedule.info.finish';
  static const scheduleInfoBreak = 'schedule.info.break';
  static const scheduleInfoArrival = 'schedule.info.arrival';
  static const scheduleInfoLeaving = 'schedule.info.leaving';
  static const scheduleInfoStartRounding = 'schedule.info.startRounding';
  static const scheduleInfoFinishRounding = 'schedule.info.finishRounding';

  // Employee groups (Figma HR / Employee groups 1340:2 to 1354:7)
  static const groupsTitle = 'groups.title';
  static const groupsSubtitle = 'groups.subtitle';
  static const groupsAdd = 'groups.add';
  static const groupsSearch = 'groups.search';
  static const groupsFilterAll = 'groups.filter.all';
  static const groupsColumnName = 'groups.column.name';
  static const groupsColumnEmployees = 'groups.column.employees';
  static const groupsColumnSchedule = 'groups.column.schedule';
  static const groupsColumnStatus = 'groups.column.status';
  static const groupsColumnActions = 'groups.column.actions';
  static const groupsScheduleNone = 'groups.schedule.none';
  static const groupsScheduleDiffer = 'groups.schedule.differ';
  static const groupsScheduleNoOwn = 'groups.schedule.noOwn';
  static const groupsLoading = 'groups.loading';
  static const groupsEmptyMessage = 'groups.empty.message';
  static const groupsNoMatchMessage = 'groups.noMatch.message';
  static const groupsActionsMenu = 'groups.actions.menu';
  static const groupsManageTitle = 'groups.manage.title';
  static const groupsManageRename = 'groups.manage.rename';
  static const groupsManageRenameText = 'groups.manage.rename.text';
  static const groupsManageDeactivate = 'groups.manage.deactivate';
  static const groupsManageDeactivateText = 'groups.manage.deactivate.text';
  static const groupsManageReactivate = 'groups.manage.reactivate';
  static const groupsManageReactivateText = 'groups.manage.reactivate.text';
  static const groupsCreateTitle = 'groups.create.title';
  static const groupsCreateSubtitle = 'groups.create.subtitle';
  static const groupsStepDetails = 'groups.step.details';
  static const groupsStepEmployees = 'groups.step.employees';
  static const groupsFieldName = 'groups.field.name';
  static const groupsFieldNameHint = 'groups.field.name.hint';
  static const groupsFieldNameHelp = 'groups.field.name.help';
  static const groupsCreateSubmit = 'groups.create.submit';
  static const groupsPickerTitle = 'groups.picker.title';
  static const groupsPickerSubtitle = 'groups.picker.subtitle';
  static const groupsPickerSearch = 'groups.picker.search';
  static const groupsPickerAlsoIn = 'groups.picker.alsoIn';
  static const groupsPickerAlsoInNone = 'groups.picker.alsoIn.none';
  static const groupsPickerAdd = 'groups.picker.add';
  static const groupsPickerLoading = 'groups.picker.loading';
  static const groupsPickerEmptyMessage = 'groups.picker.empty.message';
  static const groupsRenameTitle = 'groups.rename.title';
  static const groupsRenameSave = 'groups.rename.save';
  static const groupsErrorNameEmpty = 'groups.error.name.empty';
  static const groupsErrorNameTooLong = 'groups.error.name.tooLong';
  static const groupsErrorNameDuplicate = 'groups.error.name.duplicate';
  static const groupsDeactivateTitle = 'groups.deactivate.title';
  static const groupsDeactivateText = 'groups.deactivate.text';
  static const groupsDeactivateConfirm = 'groups.deactivate.confirm';
  static const groupsCannotDeactivateTitle = 'groups.cannotDeactivate.title';
  static const groupsCannotDeactivateText = 'groups.cannotDeactivate.text';
  static const groupsCreated = 'groups.created';
  static const groupsRenamed = 'groups.renamed';
  static const groupsDeactivated = 'groups.deactivated';
  static const groupsReactivated = 'groups.reactivated';
  static const groupsMembersAdded = 'groups.members.added';
  static const groupsMemberRemoved = 'groups.member.removed';
  static const groupPageSubtitle = 'group.page.subtitle';
  static const groupPageRename = 'group.page.rename';
  static const groupPageDeactivate = 'group.page.deactivate';
  static const groupPageReactivate = 'group.page.reactivate';
  static const groupPageInactive = 'group.page.inactive';
  static const groupPageEmployeesTitle = 'group.page.employees.title';
  static const groupPageEmployeesText = 'group.page.employees.text';
  static const groupPageEmployeesNone = 'group.page.employees.none';
  static const groupPageAddEmployees = 'group.page.addEmployees';
  static const groupPageRemove = 'group.page.remove';
  static const groupPageHoursTitle = 'group.page.hours.title';
  static const groupPageHoursNoOwn = 'group.page.hours.noOwn';
  static const groupPageHoursNone = 'group.page.hours.none';
  static const groupPageHoursDiffer = 'group.page.hours.differ';
  static const groupPageHoursNoSingle = 'group.page.hours.noSingle';
  static const groupPageAddMoreEmployees = 'group.page.addMoreEmployees';
  static const groupPageSetHoursLink = 'group.page.setHoursLink';
  static const groupPageHoursSummary = 'group.page.hours.summary';
  static const groupsStepHours = 'groups.step.hours';
  static const groupsEmployeesField = 'groups.employees.field';
  static const groupsEmployeesHint = 'groups.employees.hint';
  static const groupsHoursUses = 'groups.hours.uses';
  static const groupsHoursKeep = 'groups.hours.keep';
  static const groupsHoursKeepCurrent = 'groups.hours.keepCurrent';
  static const groupsHoursUse = 'groups.hours.use';
  static const groupsEmployeesWillWork = 'groups.employees.willWork';
  static const groupsEmployeesNoneWillWork = 'groups.employees.noneWillWork';
  static const groupsEmployeesRemove = 'groups.employees.remove';
  static const groupsHoursStartHint = 'groups.hours.startHint';
  static const groupsHoursFinishHint = 'groups.hours.finishHint';
  static const groupsHoursBreak = 'groups.hours.break';
  static const groupsHoursBreakHint = 'groups.hours.breakHint';
  static const groupsErrorFinishBeforeStart = 'groups.error.finishBeforeStart';
  static const groupsErrorBreakLength = 'groups.error.breakLength';
  static const groupsErrorHoursNeedEmployee = 'groups.error.hoursNeedEmployee';
  static const groupsLoadFailed = 'groups.loadFailed';
  static const groupsManageSubtitle = 'groups.manage.subtitle';
  static const groupsRenameSubtitle = 'groups.rename.subtitle';
  static const groupsCannotDeactivateSubtitle = 'groups.cannotDeactivate.subtitle';
  static const groupsCannotDeactivateWarning = 'groups.cannotDeactivate.warning';
  static const groupsCannotDeactivateManage = 'groups.cannotDeactivate.manage';
  static const groupsPickerNoOtherGroups = 'groups.picker.noOtherGroups';
  static const groupsPickerLoadFailed = 'groups.picker.loadFailed';
  static const groupPageSetHours = 'group.page.setHours';
  static const groupPageEditHours = 'group.page.editHours';
  static const groupPageLoading = 'group.page.loading';
  static const groupRemoveTitle = 'group.remove.title';
  static const groupRemoveText = 'group.remove.text';
  static const groupRemoveConfirm = 'group.remove.confirm';
}

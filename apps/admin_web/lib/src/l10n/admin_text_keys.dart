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
  static const companyFilterAll = 'company.filter.all';
  static const companyNoneWithStatus = 'company.noneWithStatus';
  static const companyAdd = 'company.add';
  static const companyAddText = 'company.add.text';
  static const companyName = 'company.name';
  static const companyNameRequired = 'company.name.required';
  static const companyNameTaken = 'company.name.taken';
  static const companyAdded = 'company.added';
  static const companyEmployees = 'company.employees';
  static const companyViewEmployees = 'company.viewEmployees';
  static const companyLastUpdated = 'company.lastUpdated';
  static const companySave = 'company.save';
  static const companyClose = 'company.close';
  static const companyDeactivate = 'company.deactivate';
  static const companyReactivate = 'company.reactivate';
  static const companySaveFailed = 'company.saveFailed';
  static const companySaved = 'company.saved';
  static const companyDeactivated = 'company.deactivated';
  static const companyReactivated = 'company.reactivated';

  /// Plural; `{n}`.
  static const companyCount = 'company.count';
  static const companyListSubtitle = 'company.list.subtitle';
  static const companySearch = 'company.search';
  static const companyListLoading = 'company.list.loading';
  static const companyColumnName = 'company.column.name';
  static const companyColumnEmployees = 'company.column.employees';
  static const companyColumnStatus = 'company.column.status';
  static const companyColumnLastUpdated = 'company.column.lastUpdated';
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
  static const employeeColumnStatus = 'employee.column.status';
  static const employeeEmptyTitle = 'employee.empty.title';

  /// Argument: `{company}`.
  static const employeeEmptyMessage = 'employee.empty.message';
  static const employeeEmptyMessageAll = 'employee.empty.messageAll';


  static const employeeNoMatchTitle = 'employee.noMatch.title';

  /// Argument: `{search}`.
  static const employeeNoMatchMessage = 'employee.noMatch.message';
  static const employeeNoCompanyTitle = 'employee.noCompany.title';
  static const employeeNoCompanyMessage = 'employee.noCompany.message';

  // Import employees (Figma 1419:2 … 1419:404)
  static const employeeImportAction = 'employee.import.action';
  static const employeeImportBack = 'employee.import.back';
  // Import V3 (Figma 1538:2, 1538:273).
  /// Plural: "2 ready".
  static const employeeImportReadyCount = 'employee.import.readyCount';

  /// Plural: "3 with problems".
  static const employeeImportProblemCount = 'employee.import.problemCount';
  static const employeeImportDownloadSkipped = 'employee.import.downloadSkipped';
  static const employeeImportDone = 'employee.import.done';
  static const employeeImportSkippedFile = 'employee.import.skippedFile';
  static const employeeImportProblemsColumn = 'employee.import.problemsColumn';
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
  /// Plural; argument `{size}`.
  static const employeeImportFileRows = 'employee.import.file.rows';
  static const employeeImportChange = 'employee.import.change';
  static const employeeImportTableRow = 'employee.import.table.row';
  static const employeeImportTableCode = 'employee.import.table.code';
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
  static const employeeImportDoneAgain = 'employee.import.done.again';

  // Remove employee (Figma 238:3689, 238:3853)



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
  static const timeRecordsStatusToReview = 'timeRecords.status.toReview';
  static const timeRecordsStatusFinished = 'timeRecords.status.finished';
  static const timeRecordsStatusNotStarted = 'timeRecords.status.notStarted';
  static const timeRecordsAttendanceOnTime = 'timeRecords.attendance.onTime';
  static const timeRecordsAttendanceLate = 'timeRecords.attendance.late';
  static const timeRecordsAttendanceLeftEarly = 'timeRecords.attendance.leftEarly';
  static const timeRecordsStatusAll = 'timeRecords.status.all';
  static const timeRecordsStatusComplete = 'timeRecords.status.complete';
  static const timeRecordsStatusWorking = 'timeRecords.status.working';
  static const timeRecordsStatusMissingFinish = 'timeRecords.status.missingFinish';
  static const timeRecordsStatusMissingStart = 'timeRecords.status.missingStart';
  static const timeRecordsStatusCorrected = 'timeRecords.status.corrected';
  static const timeRecordsStatusPendingReview = 'timeRecords.status.pendingReview';
  static const timeRecordsStatusNonWork = 'timeRecords.status.nonWork';
  static const timeRecordsStatusNoRegistration = 'timeRecords.status.noRegistration';
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

  // Time corrections (Figma 160:220, 160:338, 272:457, 273:166, 272:547)
  static const timeRecordsFix = 'timeRecords.fix';
  static const timeRecordsReview = 'timeRecords.review';
  static const timeRecordDayCorrectTime = 'timeRecord.day.correctTime';
  static const timeRecordDayReview = 'timeRecord.day.review';
  static const timeRecordDayTimeline = 'timeRecord.day.timeline';
  static const timeRecordDayTimelineHide = 'timeRecord.day.timelineHide';
  static const timeRecordDayCorrectedBy = 'timeRecord.day.correctedBy';
  static const timeRecordDayOriginal = 'timeRecord.day.original';
  static const timeRecordDayPending = 'timeRecord.day.pending';
  static const timeRecordDayNonWork = 'timeRecord.day.nonWork';
  static const timeRecordEventRegistered = 'timeRecord.event.registered';
  static const timeRecordEventRequested = 'timeRecord.event.requested';
  static const timeRecordEventCorrected = 'timeRecord.event.corrected';
  static const timeRecordEventRejected = 'timeRecord.event.rejected';
  static const timeRecordEventNonWork = 'timeRecord.event.nonWork';
  static const timeRecordEventReplaced = 'timeRecord.event.replaced';
  static const timeRecordBoundaryStart = 'timeRecord.boundary.start';
  static const timeRecordBoundaryFinish = 'timeRecord.boundary.finish';
  static const timeCorrectTitle = 'timeCorrect.title';
  static const timeCorrectActualStart = 'timeCorrect.actualStart';
  static const timeCorrectActualFinish = 'timeCorrect.actualFinish';
  static const timeCorrectRegisteredStart = 'timeCorrect.registeredStart';
  static const timeCorrectRegisteredFinish = 'timeCorrect.registeredFinish';
  static const timeCorrectRoundedHint = 'timeCorrect.roundedHint';
  static const timeCorrectTimeHint = 'timeCorrect.timeHint';
  static const timeCorrectTimeInvalid = 'timeCorrect.timeInvalid';
  static const timeCorrectTimeRejected = 'timeCorrect.timeRejected';
  static const timeCorrectNoRounding = 'timeCorrect.noRounding';
  static const timeCorrectNothingChanged = 'timeCorrect.nothingChanged';
  static const timeCorrectReason = 'timeCorrect.reason';
  static const timeCorrectReasonHint = 'timeCorrect.reasonHint';
  static const timeCorrectReasonRequired = 'timeCorrect.reasonRequired';
  static const timeCorrectAudit = 'timeCorrect.audit';
  static const timeCorrectAuditText = 'timeCorrect.auditText';
  static const timeCorrectSave = 'timeCorrect.save';
  static const timeResolveFinishTitle = 'timeResolve.finishTitle';
  static const timeResolveStartTitle = 'timeResolve.startTitle';
  static const timeResolveDetails = 'timeResolve.details';
  static const timeResolveChoose = 'timeResolve.choose';
  static const timeResolveSetFinish = 'timeResolve.setFinish';
  static const timeResolveSetFinishText = 'timeResolve.setFinishText';
  static const timeResolveSetStart = 'timeResolve.setStart';
  static const timeResolveSetStartText = 'timeResolve.setStartText';
  static const timeResolveNonWork = 'timeResolve.nonWork';
  static const timeResolveNonWorkText = 'timeResolve.nonWorkText';
  static const timeResolveNonWorkFinishNote = 'timeResolve.nonWorkFinishNote';
  static const timeResolveNonWorkStartNote = 'timeResolve.nonWorkStartNote';
  static const timeResolveNothingToMark = 'timeResolve.nothingToMark';
  static const timeResolveActualStart = 'timeResolve.actualStart';
  static const timeResolveRoundedStart = 'timeResolve.roundedStart';
  static const timeResolveActualFinish = 'timeResolve.actualFinish';
  static const timeResolveRoundedFinish = 'timeResolve.roundedFinish';
  static const timeResolveReason = 'timeResolve.reason';
  static const timeResolveHistory = 'timeResolve.history';
  static const timeResolveConfirmNonWork = 'timeResolve.confirmNonWork';
  static const timeReviewTitle = 'timeReview.title';
  static const timeReviewDetected = 'timeReview.detected';
  static const timeReviewRequested = 'timeReview.requested';
  static const timeReviewRegistered = 'timeReview.registered';
  static const timeReviewNoChange = 'timeReview.noChange';
  static const timeReviewReason = 'timeReview.reason';
  static const timeReviewRule = 'timeReview.rule';
  static const timeReviewApprove = 'timeReview.approve';
  static const timeReviewReject = 'timeReview.reject';
  static const timeSavedTitle = 'timeSaved.title';
  static const timeSavedText = 'timeSaved.text';
  static const timeSavedFinish = 'timeSaved.finish';
  static const timeSavedStart = 'timeSaved.start';
  static const timeSavedNonWork = 'timeSaved.nonWork';
  static const timeSavedApproved = 'timeSaved.approved';
  static const timeSavedRejected = 'timeSaved.rejected';
  static const timeSavedBack = 'timeSaved.back';

  static const employeeAddAction = 'employee.add.action';
  static const employeeAddTitle = 'employee.add.title';
  static const employeeColumnSchedule = 'employee.column.schedule';
  static const employeeFilterCompanyHint = 'employee.filter.company.hint';
  static const employeeFilterCompanyAll = 'employee.filter.company.all';
  static const employeeFilterCompanyFailed = 'employee.filter.company.failed';
  static const employeeNoCompany = 'employee.noCompany';
  static const employeeNoMatch = 'employee.noMatch';
  // Add employee (Figma 1536:2, 1536:195, 1536:389, 1536:569).
  /// Arguments: `{n}`, `{total}`, `{step}` ("Details").
  static const employeeAddProgress = 'employee.add.progress';
  static const employeeAddStepDetails = 'employee.add.step.details';
  static const employeeAddStepWork = 'employee.add.step.work';
  static const employeeAddStepSetUp = 'employee.add.step.setUp';

  /// Argument: `{name}`.
  static const employeeAddAdded = 'employee.add.added';
  static const employeeFieldOptional = 'employee.field.optional';
  static const employeeFieldMissingFirstName = 'employee.field.missing.firstName';
  static const employeeFieldMissingLastName = 'employee.field.missing.lastName';
  static const employeeFieldMissingCode = 'employee.field.missing.code';
  static const employeeFieldMissingCompany = 'employee.field.missing.company';
  static const employeeFieldEmailHint = 'employee.field.email.hint';
  static const employeeAddHours = 'employee.add.hours';

  /// Arguments: `{hours}`, `{group}`.
  static const employeeAddHoursFrom = 'employee.add.hours.from';
  static const employeeAddHoursNone = 'employee.add.hours.none';
  static const employeeAddHoursChoose = 'employee.add.hours.choose';

  /// Argument: `{name}`. Add employee closed because the QR was used.
  static const employeeAddSetUp = 'employee.add.setUp';
  static const employeeAddContinue = 'employee.add.continue';
  static const employeeFieldCodeHint = 'employee.field.code.hint';
  static const employeeFieldEmail = 'employee.field.email';
  static const employeeFieldCompanies = 'employee.field.companies';
  static const employeeFieldCompaniesHint = 'employee.field.companies.hint';
  static const employeeFieldGroups = 'employee.field.groups';
  static const employeeFieldGroupsHint = 'employee.field.groups.hint';
  static const employeeFieldScheduleChoose = 'employee.field.schedule.choose';
  static const employeeFieldErrorEmail = 'employee.field.error.email';
  static const employeeFieldErrorUnavailable = 'employee.field.error.unavailable';
  static const employeeAddLoading = 'employee.add.loading';

  /// Argument: `{name}`.
  static const employeeAddSuccess = 'employee.add.success';
  static const employeeFieldFirstName = 'employee.field.firstName';
  static const employeeFieldLastName = 'employee.field.lastName';
  static const employeeFieldCode = 'employee.field.code';
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


  /// Arguments: `{company}`, `{code}`.
  static const employeeDetailsSubtitle = 'employee.details.subtitle';


  /// Arguments: `{name}`, `{company}`.
  static const employeeQrSubtitle = 'employee.qr.subtitle';

  // The QR pop-up (Figma 1532:181 onboarding, 1532:772 recovery, 1532:1363 expired).
  static const temporaryQrOnboardingTitle = 'employee.temporaryQr.onboarding.title';
  static const temporaryQrRecoveryTitle = 'employee.temporaryQr.recovery.title';
  static const temporaryQrLoading = 'employee.temporaryQr.loading';

  /// Argument: `{name}`, the employee's first name.
  static const temporaryQrOnboardingInstruction = 'employee.temporaryQr.onboarding.instruction';

  /// Argument: `{name}`, the employee's first name.
  static const temporaryQrRecoveryInstruction = 'employee.temporaryQr.recovery.instruction';

  /// Argument: `{time}`, the time left ("09:57").
  static const temporaryQrFacts = 'employee.temporaryQr.facts';
  static const temporaryQrMakeNew = 'employee.temporaryQr.makeNew';
  static const temporaryQrDone = 'employee.temporaryQr.done';
  static const temporaryQrClose = 'employee.temporaryQr.close';
  static const temporaryQrExpired = 'employee.temporaryQr.expired';
  static const temporaryQrExpiredText = 'employee.temporaryQr.expired.text';

  /// Argument: `{name}`.
  static const temporaryQrSemantics = 'employee.temporaryQr.semantics';

  /// Argument: `{name}`. Said once the employee finished with the QR.
  static const employeeSetUpDone = 'employee.setUp.done';
  static const employeeNewPasswordDone = 'employee.newPassword.done';

  static const employeeResetAccessTitle = 'employee.resetAccess.title';

  static const employeeResetAccessSubtitle = 'employee.resetAccess.subtitle';
  static const employeeResetAccessEffectSessions = 'employee.resetAccess.effects.sessions';
  static const employeeResetAccessEffectRecovery = 'employee.resetAccess.effects.recovery';
  static const employeeResetAccessEffectQr = 'employee.resetAccess.effects.qr';
  static const employeeResetAccessConfirm = 'employee.resetAccess.confirm';

  /// Argument: `{name}`.
  static const employeeResetAccessSuccess = 'employee.resetAccess.success';
  static const employeeResetAccessNotActivated = 'employee.resetAccess.notActivated';

  // Manage employee assignments (Figma Employees 04–07)
  /// One line above each tab's list (Figma 1537:*). Argument: `{name}`.
  static const assignmentsCompaniesNote = 'employee.assignments.companies.note';
  static const assignmentsGroupsNote = 'employee.assignments.groups.note';
  static const assignmentsLanguageNote = 'employee.assignments.language.note';
  static const assignmentsAccessNote = 'employee.assignments.access.note';
  static const assignmentsTitle = 'employee.assignments.title';

  static const assignmentsLoading = 'employee.assignments.loading';
  static const assignmentsSave = 'employee.assignments.save';
  static const assignmentsSaved = 'employee.assignments.saved';
  static const assignmentsTabCompanies = 'employee.assignments.tab.companies';
  static const assignmentsTabGroups = 'employee.assignments.tab.groups';

  // Remove Company / Group confirmation (Figma 207:329, 207:441)
  /// Arguments: `{name}` (first name), `{what}` (the company or group).
  static const removeAssignmentTitle = 'employee.assignments.remove.title';
  static const removeCompanyText = 'employee.assignments.remove.company.text';
  static const removeGroupText = 'employee.assignments.remove.group.text';
  static const removeAssignmentConfirm = 'employee.assignments.remove.confirm';
  static const assignmentsTabLanguage = 'employee.assignments.tab.language';
  static const assignmentsTabAccess = 'employee.assignments.tab.access';

  // Schedules (Figma HR / Schedules 1317:2 to 1333:196)
  static const scheduleTitle = 'schedule.title';
  static const scheduleListLoadFailed = 'schedule.list.loadFailed';
  static const scheduleInfoHours = 'schedule.info.hours';
  static const scheduleCount = 'schedule.count';
  static const scheduleFilterAll = 'schedule.filter.all';
  static const scheduleNoDifferTitle = 'schedule.noDiffer.title';
  static const scheduleNoDifferText = 'schedule.noDiffer.text';
  static const scheduleNoActiveTitle = 'schedule.noActive.title';
  static const scheduleNoActiveText = 'schedule.noActive.text';
  static const scheduleEmployees = 'schedule.employees';
  static const scheduleStatusLine = 'schedule.statusLine';
  static const scheduleRowWorkDays = 'schedule.row.workDays';
  static const scheduleRowHours = 'schedule.row.hours';
  static const scheduleRowBreak = 'schedule.row.break';
  static const scheduleRowTolerance = 'schedule.row.tolerance';
  static const scheduleRowRounding = 'schedule.row.rounding';
  static const scheduleRowGroup = 'schedule.row.group';
  static const scheduleRowArrival = 'schedule.row.arrival';
  static const scheduleRowLeaving = 'schedule.row.leaving';
  static const scheduleRowStartRounding = 'schedule.row.startRounding';
  static const scheduleRowFinishRounding = 'schedule.row.finishRounding';
  static const scheduleHoursRange = 'schedule.hoursRange';
  static const scheduleToleranceValue = 'schedule.tolerance.value';
  static const scheduleRoundingSame = 'schedule.rounding.same';
  static const scheduleRoundingWordUp = 'schedule.rounding.word.up';
  static const scheduleRoundingWordDown = 'schedule.rounding.word.down';
  static const scheduleDifferNote = 'schedule.differ.note';
  static const scheduleRemoveHours = 'schedule.remove.hours';
  static const scheduleRemoveBreak = 'schedule.remove.break';
  static const scheduleRemoveHoursTitle = 'schedule.remove.hours.title';
  static const scheduleRemoveBreakTitle = 'schedule.remove.break.title';
  static const scheduleRemoveHoursText = 'schedule.remove.hours.text';
  static const scheduleRemoveBreakText = 'schedule.remove.break.text';
  static const scheduleRemovedHours = 'schedule.removed.hours';
  static const scheduleRemovedBreak = 'schedule.removed.break';
  static const scheduleChangeFailed = 'schedule.changeFailed';
  static const scheduleEdit = 'schedule.edit';
  static const scheduleOpenGroup = 'schedule.openGroup';
  static const scheduleStepHours = 'schedule.step.hours';
  static const scheduleStepRules = 'schedule.step.rules';
  static const scheduleFormPerDay = 'schedule.form.perDay';
  static const scheduleFormSameEveryDay = 'schedule.form.sameEveryDay';
  static const scheduleReviewApplies = 'schedule.review.applies';
  static const scheduleDayLetter1 = 'schedule.day.letter.1';
  static const scheduleDayLetter2 = 'schedule.day.letter.2';
  static const scheduleDayLetter3 = 'schedule.day.letter.3';
  static const scheduleDayLetter4 = 'schedule.day.letter.4';
  static const scheduleDayLetter5 = 'schedule.day.letter.5';
  static const scheduleDayLetter6 = 'schedule.day.letter.6';
  static const scheduleDayLetter7 = 'schedule.day.letter.7';
  static const scheduleAddAction = 'schedule.add.action';
  static const scheduleListSubtitle = 'schedule.list.subtitle';
  static const scheduleSearch = 'schedule.search';
  static const scheduleListLoading = 'schedule.list.loading';
  static const scheduleColumnName = 'schedule.column.name';
  static const scheduleColumnStatus = 'schedule.column.status';
  static const scheduleStatusDiffer = 'schedule.status.differ';
  static const scheduleEmptyTitle = 'schedule.empty.title';
  static const scheduleEmptyMessage = 'schedule.empty.message';
  static const scheduleNoMatchTitle = 'schedule.noMatch.title';
  static const scheduleNoMatchMessage = 'schedule.noMatch.message';
  static const scheduleSaved = 'schedule.saved';
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
  static const scheduleFormGroupHint = 'schedule.form.group.hint';
  static const scheduleFormStart = 'schedule.form.start';
  static const scheduleFormFinish = 'schedule.form.finish';
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
  static const scheduleFormTimeHint = 'schedule.form.timeHint';
  static const scheduleFormMinutesUnit = 'schedule.form.minutesUnit';
  static const scheduleStepReview = 'schedule.step.review';
  static const scheduleColumnDaysHours = 'schedule.column.daysHours';
  static const scheduleColumnBreak = 'schedule.column.break';
  static const scheduleBreakMinutes = 'schedule.breakMinutes';
  static const scheduleFormConflict = 'schedule.form.conflict';
  static const scheduleErrorBreakIncomplete = 'schedule.error.breakIncomplete';
  static const scheduleInfoGroup = 'schedule.info.group';
  static const scheduleInfoDays = 'schedule.info.days';
  static const scheduleInfoBreak = 'schedule.info.break';
  static const scheduleInfoArrival = 'schedule.info.arrival';
  static const scheduleInfoLeaving = 'schedule.info.leaving';
  static const scheduleInfoStartRounding = 'schedule.info.startRounding';
  static const scheduleInfoFinishRounding = 'schedule.info.finishRounding';

  // Employee groups (Figma HR / Employee groups 1340:2 to 1354:7)
  static const groupsTitle = 'groups.title';
  static const groupsNewGroup = 'groups.newGroup';
  static const scheduleStepGroup = 'schedule.step.group';
  static const groupsFieldNameLabel = 'groups.field.nameLabel';
  static const groupsEmployeesChosen = 'groups.employees.chosen';
  static const groupsThisGroup = 'groups.thisGroup';
  static const groupsPickerName = 'groups.picker.name';
  static const groupsHoursFrom = 'groups.hours.from';
  static const groupsHoursFromOwn = 'groups.hours.fromOwn';
  static const groupsPickerAddNone = 'groups.picker.addNone';
  static const groupsCount = 'groups.count';
  static const groupsEmptyTitle = 'groups.empty.title';
  static const groupsNoMatchTitle = 'groups.noMatch.title';
  static const groupsNoInactiveTitle = 'groups.noInactive.title';
  static const groupsNoInactiveText = 'groups.noInactive.text';
  static const groupsNoActiveTitle = 'groups.noActive.title';
  static const groupsNoActiveText = 'groups.noActive.text';
  static const groupsSubtitle = 'groups.subtitle';
  static const groupsAdd = 'groups.add';
  static const groupsSearch = 'groups.search';
  static const groupsFilterAll = 'groups.filter.all';
  static const groupsColumnName = 'groups.column.name';
  static const groupsColumnEmployees = 'groups.column.employees';
  static const groupsColumnSchedule = 'groups.column.schedule';
  static const groupsColumnStatus = 'groups.column.status';
  static const groupsScheduleNone = 'groups.schedule.none';
  static const groupsScheduleDiffer = 'groups.schedule.differ';
  static const groupsScheduleNoOwn = 'groups.schedule.noOwn';
  static const groupsLoading = 'groups.loading';
  static const groupsEmptyMessage = 'groups.empty.message';
  static const groupsNoMatchMessage = 'groups.noMatch.message';
  static const groupsCreateTitle = 'groups.create.title';
  static const groupsFieldNameHint = 'groups.field.name.hint';
  static const groupsCreateSubmit = 'groups.create.submit';
  static const groupsPickerTitle = 'groups.picker.title';
  static const groupsPickerSubtitle = 'groups.picker.subtitle';
  static const groupsPickerSearch = 'groups.picker.search';
  static const groupsPickerAlsoIn = 'groups.picker.alsoIn';
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
  static const groupPageRename = 'group.page.rename';
  static const groupPageDeactivate = 'group.page.deactivate';
  static const groupPageReactivate = 'group.page.reactivate';
  static const groupsHoursLater = 'groups.hoursLater';
  static const groupsReviewEmployees = 'groups.review.employees';
  static const groupsReviewNoEmployees = 'groups.review.noEmployees';
  static const groupsReviewKeeps = 'groups.review.keeps';
  static const groupsReviewHoursLater = 'groups.review.hoursLater';
  static const groupsReviewNote = 'groups.review.note';
  static const groupsEmployeesField = 'groups.employees.field';
  static const groupsEmployeesAllKeep = 'groups.employees.allKeep';
  static const groupsErrorFinishBeforeStart = 'groups.error.finishBeforeStart';
  static const groupsErrorHoursNeedEmployee = 'groups.error.hoursNeedEmployee';
  static const groupsLoadFailed = 'groups.loadFailed';
  static const groupsPickerLoadFailed = 'groups.picker.loadFailed';
  // Group page (Figma 1455:2)
  static const groupDetailBack = 'group.detail.back';
  static const groupDetailEmployeeCount = 'group.detail.employeeCount';
  static const groupDetailCompanyCount = 'group.detail.companyCount';
  static const groupDetailInactiveText = 'group.detail.inactiveText';
  static const groupDetailNoBreak = 'group.detail.noBreak';
  static const groupDetailNoticeOne = 'group.detail.notice.single';
  static const groupDetailNoticeMany = 'group.detail.notice.several';
  static const groupDetailNoticeAction = 'group.detail.notice.action';
  static const groupDetailEmployees = 'group.detail.employees';
  static const groupDetailSearch = 'group.detail.search';
  static const groupDetailAddEmployees = 'group.detail.addEmployees';
  static const groupDetailColumnEmployee = 'group.detail.column.employee';
  static const groupDetailColumnCompanies = 'group.detail.column.companies';
  static const groupDetailColumnOtherGroups = 'group.detail.column.otherGroups';
  static const groupDetailColumnHours = 'group.detail.column.hours';
  static const groupDetailHoursThisGroup = 'group.detail.hours.thisGroup';
  static const groupDetailHoursNeedsChoice = 'group.detail.hours.needsChoice';
  static const groupDetailHoursNone = 'group.detail.hours.none';
  static const groupDetailRemove = 'group.detail.remove';
  static const groupDetailEmployeesNone = 'group.detail.employeesNone';
  static const groupDetailEmployeesNoneText = 'group.detail.employeesNoneText';
  static const groupDetailNoMatch = 'group.detail.noMatch';
  static const groupDetailHoursPanel = 'group.detail.hoursPanel';
  static const groupDetailToleranceValue = 'group.detail.toleranceValue';
  static const groupDetailHoursEmptyText = 'group.detail.hoursEmptyText';
  static const groupDetailHoursNoSingleText = 'group.detail.hoursNoSingleText';
  static const groupDetailHoursDifferText = 'group.detail.hoursDifferText';
  static const groupDetailChooseTitle = 'group.detail.choose.title';
  static const groupDetailChooseText = 'group.detail.choose.text';
  static const groupDetailChooseSave = 'group.detail.choose.save';
  static const groupDetailChooseSaved = 'group.detail.choose.saved';
  static const groupDetailChooseNoHours = 'group.detail.choose.noHours';
  static const groupPageSetHours = 'group.page.setHours';
  static const groupPageEditHours = 'group.page.editHours';
  static const groupPageLoading = 'group.page.loading';
  static const groupPageLoadFailed = 'group.page.loadFailed';
  static const groupDetailStatusLine = 'group.detail.statusLine';
  static const groupDetailNoEmployees = 'group.detail.noEmployees';
  static const groupDetailPeople = 'group.detail.people';
  static const groupDetailEdit = 'group.detail.edit';
  static const groupDetailHoursAll = 'group.detail.hoursAll';
  static const groupsCannotDeactivateOk = 'groups.cannotDeactivate.ok';
  static const scheduleRoundingShortUp = 'schedule.rounding.short.up';
  static const scheduleRoundingShortDown = 'schedule.rounding.short.down';
  static const scheduleRoundingCompact = 'schedule.rounding.compact';
  static const groupRemoveTitle = 'group.remove.title';
  static const groupRemoveText = 'group.remove.text';
  static const groupRemoveConfirm = 'group.remove.confirm';

  static const timeRecordDayTransport = 'timeRecord.day.transport';
  static const timeRecordDayTravelText = 'timeRecord.day.travelText';
  static const timeRecordDayTrips = 'timeRecord.day.trips';
  static const timeRecordDayAway = 'timeRecord.day.away';
  static const timeRecordDayAwayText = 'timeRecord.day.away.text';
  static const timeRecordDayAwayValue = 'timeRecord.day.away.value';

  // Sign-in (Figma HR / Sign in 1469:2 to 1469:53)
  static const signInForgot = 'hr.signIn.forgot';
  static const signInErrorInactive = 'hr.signIn.error.inactive';
  static const noAccessTitle = 'hr.noAccess.title';
  static const noAccessText = 'hr.noAccess.text';
  static const signOut = 'hr.signOut';

  // Reports (Figma HR / Reports V1 1467:2 to 1467:631)
  static const navReports = 'nav.reports';
  static const navLists = 'nav.lists';
  static const listsTitle = 'lists.title';
  static const listsSubtitle = 'lists.subtitle';
  static const listsMissingTitle = 'lists.missingTitle';
  static const listsMissingText = 'lists.missingText';
  static const listsAddMissing = 'lists.addMissing';
  static const listsColumnList = 'lists.column.list';
  static const listsColumnEntries = 'lists.column.entries';
  static const listsColumnStatus = 'lists.column.status';
  static const listsReady = 'lists.ready';
  static const listsMissingCount = 'lists.missingCount';
  static const listsEntriesOf = 'lists.entriesOf';
  static const listsNote = 'lists.note';
  static const listsLoading = 'lists.loading';
  static const listsLoadFailed = 'lists.loadFailed';
  static const listsAddFailed = 'lists.addFailed';
  static const listsEntryMissing = 'lists.entryMissing';
  static const listsEntryAdded = 'lists.entryAdded';
  static const listsReadsByName = 'lists.readsByName';
  static const listsFree = 'lists.free';
  static const listsAddIt = 'lists.addIt';
  static const listsAddBoth = 'lists.addBoth';
  static const listsAddAll = 'lists.addAll';
  static const listsClose = 'lists.close';

  /// One list's name and what it is for: `lists.kind.<kind>` and `….text`.
  static String listName(String kind) => 'lists.kind.$kind';
  static String listText(String kind) => 'lists.kind.$kind.text';
  static const navDashboard = 'nav.dashboard';
  static const navProjects = 'nav.projects';
  static const navTerminals = 'nav.terminals';
  static const terminalsTitle = 'terminals.title';
  static const terminalsSubtitle = 'terminals.subtitle';
  static const terminalAdd = 'terminal.add';
  static const terminalsSearch = 'terminals.search';
  static const terminalsLoading = 'terminals.loading';
  static const terminalsLoadFailed = 'terminals.loadFailed';
  static const terminalCount = 'terminals.count';
  static const terminalColumnTerminal = 'terminal.column.terminal';
  static const terminalColumnType = 'terminal.column.type';
  static const terminalColumnStatus = 'terminal.column.status';
  static const terminalColumnSeen = 'terminal.column.seen';
  static const terminalOnline = 'terminal.status.online';
  static const terminalOffline = 'terminal.status.offline';
  static const terminalNotConnected = 'terminal.status.notConnected';
  static const terminalInactive = 'terminal.status.inactive';
  static const terminalStatusSeen = 'terminal.statusSeen';
  static const terminalSeenNow = 'terminal.seen.now';
  static const terminalSeenMinutes = 'terminal.seen.minutes';
  static const terminalSeenYesterday = 'terminal.seen.yesterday';
  static const terminalAddTitle = 'terminal.addTitle';
  static const terminalEditTitle = 'terminal.editTitle';
  static const terminalName = 'terminal.name';
  static const terminalSerial = 'terminal.serial';
  static const terminalSerialHint = 'terminal.serialHint';
  static const terminalVehicleNameHint = 'terminal.vehicleNameHint';
  static const terminalLastScan = 'terminal.lastScan';
  static const terminalContinue = 'terminal.continue';
  static const terminalSave = 'terminal.save';
  static const terminalErrorName = 'terminal.error.name';
  static const terminalErrorSerial = 'terminal.error.serial';
  static const terminalSerialTaken = 'terminal.error.serialTaken';
  static const terminalConnectTitle = 'terminal.connect.title';
  static const terminalConnectText = 'terminal.connect.text';
  static const terminalWaiting = 'terminal.connect.waiting';
  static const terminalTimeLeft = 'terminal.connect.timeLeft';
  static const terminalCodeExpired = 'terminal.connect.expired';
  static const terminalFinishLater = 'terminal.connect.later';
  static const terminalNewCode = 'terminal.connect.newCode';
  static const terminalReadyTitle = 'terminal.ready.title';
  static const terminalReadyText = 'terminal.ready.text';
  static const terminalDone = 'terminal.done';
  static const terminalEdit = 'terminal.edit';
  static const terminalReconnect = 'terminal.reconnect';
  static const terminalConnect = 'terminal.connect';
  static const terminalDeactivate = 'terminal.deactivate';
  static const terminalReactivate = 'terminal.reactivate';
  static const terminalDeactivateTitle = 'terminal.deactivate.title';
  static const terminalDeactivateText = 'terminal.deactivate.text';
  static const terminalChangeFailed = 'terminal.changeFailed';
  // Terminals V4 (Figma 1545:111 … 1545:955).
  static const terminalsFilterAll = 'terminals.filter.all';
  static const terminalsEmptyTitle = 'terminals.empty.title';
  static const terminalsEmptyText = 'terminals.empty.text';
  static const terminalsNoMatchTitle = 'terminals.noMatch.title';
  static const terminalsNoMatchText = 'terminals.noMatch.text';
  static const terminalsNoInactiveTitle = 'terminals.noInactive.title';
  static const terminalsNoInactiveText = 'terminals.noInactive.text';
  static const terminalsNoActiveTitle = 'terminals.noActive.title';
  static const terminalsNoActiveText = 'terminals.noActive.text';
  static const terminalInactiveNote = 'terminal.inactive.note';
  static const terminalSaved = 'terminal.saved';
  static const terminalDeactivated = 'terminal.deactivated';
  static const terminalReactivated = 'terminal.reactivated';

  // Projects (Figma 647:1192)
  static const projectsTitle = 'project.list.title';
  static const projectsSubtitle = 'project.list.subtitle';
  static const projectsSearch = 'project.list.search';
  static const projectsLoading = 'project.list.loading';
  static const projectsLoadFailed = 'project.list.loadFailed';
  static const projectsEmpty = 'project.list.empty';
  static const projectsNoMatch = 'project.list.noMatch';
  static const projectsCount = 'project.list.count';
  static const projectAdd = 'project.add';
  static const projectColumnProject = 'project.column.project';
  static const projectColumnPlace = 'project.column.place';
  static const projectColumnStatus = 'project.column.status';
  static const projectColumnLastUsed = 'project.column.lastUsed';
  static const projectPlaceClient = 'project.place.client';
  static const projectPlaceClientOnly = 'project.place.clientOnly';
  static const projectPlaceWorkshop = 'project.place.workshop';
  static const projectPlaceWorkshopOnly = 'project.place.workshopOnly';
  static const projectActive = 'project.status.active';
  static const projectInactive = 'project.status.inactive';
  static const projectNeverUsed = 'project.neverUsed';
  static const projectAddTitle = 'project.form.addTitle';
  static const projectEditTitle = 'project.form.editTitle';
  static const projectClientText = 'project.form.clientText';
  static const projectWorkshopText = 'project.form.workshopText';
  static const projectKindClient = 'project.form.kindClient';
  static const projectKindWorkshop = 'project.form.kindWorkshop';
  static const projectSapNumber = 'project.form.sapNumber';
  static const projectName = 'project.form.name';
  static const projectWorkshop = 'project.form.workshop';
  static const projectWorkshopHint = 'project.form.workshopHint';
  static const projectChoose = 'project.form.choose';
  static const projectCreate = 'project.form.create';
  static const projectSave = 'project.form.save';
  static const projectDeactivate = 'project.form.deactivate';
  static const projectReactivate = 'project.form.reactivate';
  static const projectErrorSapNumber = 'project.error.sapNumber';
  static const projectErrorName = 'project.error.name';
  static const projectErrorNameTaken = 'project.error.nameTaken';
  static const projectErrorWorkshop = 'project.error.workshop';

  // Dashboard (Figma 1470:2)
  static const dashboardTitle = 'dashboard.title';
  static const dashboardLoading = 'dashboard.loading';
  static const dashboardLoadFailed = 'dashboard.loadFailed';
  static const dashboardCompanies = 'dashboard.companies';
  static const dashboardCompaniesNote = 'dashboard.companies.note';
  static const dashboardEmployees = 'dashboard.employees';
  static const dashboardEmployeesNote = 'dashboard.employees.note';
  static const dashboardLocations = 'dashboard.locations';
  static const dashboardLocationsNote = 'dashboard.locations.note';
  static const dashboardHours = 'dashboard.hours';
  static const dashboardHoursTravel = 'dashboard.hours.travel';
  static const dashboardHoursNote = 'dashboard.hours.note';
  static const dashboardHoursDay = 'dashboard.hours.perDay';
  static const dashboardHoursWeek = 'dashboard.hours.perWeek';
  static const dashboardHoursMonth = 'dashboard.hours.perMonth';
  static const dashboardRegistered = 'dashboard.hours.registered';
  static const dashboardPlanned = 'dashboard.hours.planned';
  static const dashboardBarTooltip = 'dashboard.hours.tooltip';
  static const dashboardToday = 'dashboard.today';
  static const dashboardTodayNote = 'dashboard.today.note';
  static const dashboardScheduled = 'dashboard.today.scheduled';
  static const dashboardWorking = 'dashboard.today.working';
  static const dashboardFinished = 'dashboard.today.finished';
  static const dashboardNotStarted = 'dashboard.today.notStarted';
  static const dashboardByCompany = 'dashboard.byCompany';
  static const dashboardByCompanyNote = 'dashboard.byCompany.note';
  static const dashboardAttendance = 'dashboard.attendance';
  static const dashboardAttendanceNote = 'dashboard.attendance.note';
  static const dashboardPercent = 'dashboard.attendance.percent';
  static const dashboardOnTimeCaption = 'dashboard.attendance.onTimeCaption';
  static const dashboardOnTime = 'dashboard.attendance.onTime';
  static const dashboardLate = 'dashboard.attendance.late';
  static const dashboardLeftEarly = 'dashboard.attendance.leftEarly';
  static const dashboardToReview = 'dashboard.attendance.toReview';
  static const dashboardAttention = 'dashboard.attention';
  static const dashboardCorrections = 'dashboard.attention.corrections';
  static const dashboardDaysToReview = 'dashboard.attention.daysToReview';
  static const dashboardNotSetUp = 'dashboard.attention.notSetUp';
  static const dashboardClearTitle = 'dashboard.attention.clearTitle';
  static const dashboardClearText = 'dashboard.attention.clearText';
  static const periodToday = 'dashboard.period.today';
  static const periodYesterday = 'dashboard.period.yesterday';
  static const periodLast7Days = 'dashboard.period.last7Days';
  static const periodLast30Days = 'dashboard.period.last30Days';
  static const periodThisMonth = 'dashboard.period.thisMonth';
  static const periodLastMonth = 'dashboard.period.lastMonth';
  static const periodThisYear = 'dashboard.period.thisYear';
  static const periodCustom = 'dashboard.period.custom';
  static const periodApply = 'dashboard.period.apply';
  static const periodCancel = 'dashboard.period.cancel';
  static const periodPreviousMonth = 'dashboard.period.previousMonth';
  static const periodNextMonth = 'dashboard.period.nextMonth';
  static const periodFrom = 'dashboard.period.from';
  static const periodTo = 'dashboard.period.to';
  static const periodDismiss = 'dashboard.period.dismiss';
  static const reportTitle = 'report.title';
  static const reportSubtitle = 'report.subtitle';
  static const reportExport = 'report.export';
  static const reportExportExcel = 'report.export.excel';
  static const reportExportCsv = 'report.export.csv';
  static const reportPeriod = 'report.period';
  static const reportCompany = 'report.company';
  static const reportCompanyAll = 'report.company.all';
  static const reportSearch = 'report.search';
  static const reportPlanned = 'report.planned';
  static const reportRegistered = 'report.registered';
  static const reportTravel = 'report.travel';
  static const reportDifference = 'report.difference';
  static const reportToReview = 'report.toReview';
  static const reportColumnEmployee = 'report.column.employee';
  static const reportColumnKilometres = 'report.column.kilometres';
  static const reportColumnToReview = 'report.column.toReview';
  static const reportKilometres = 'report.kilometres';
  static const reportUnknownDistance = 'report.unknownDistance';
  static const reportFileTrips = 'report.file.trips';
  static const reportFileKilometres = 'report.file.kilometres';
  static const reportFileUnknownTrips = 'report.file.unknownTrips';
  static const reportColumnDay = 'report.column.day';
  static const reportColumnStart = 'report.column.start';
  static const reportColumnFinish = 'report.column.finish';
  static const reportColumnStatus = 'report.column.status';
  static const reportHours = 'report.hours';
  static const reportHoursMinutes = 'report.hoursMinutes';
  static const reportDays = 'report.days';
  static const reportEmployees = 'report.employees';
  static const reportDayAway = 'report.day.away';
  static const reportDaysNone = 'report.daysNone';
  static const reportClose = 'report.close';
  static const reportLoading = 'report.loading';
  static const reportLoadFailed = 'report.loadFailed';
  static const reportNoMatch = 'report.noMatch';
  static const reportEmptyTitle = 'report.empty.title';
  static const reportEmptyText = 'report.empty.text';
  static const reportFileCode = 'report.file.code';
  static const reportFileFirstName = 'report.file.firstName';
  static const reportFileLastName = 'report.file.lastName';
  static const reportFilePlanned = 'report.file.planned';
  static const reportFileRegistered = 'report.file.registered';
  static const reportFileTravel = 'report.file.travel';
  static const reportFileDifference = 'report.file.difference';
  static const reportFileToReview = 'report.file.toReview';
  static const reportViewEmployees = 'report.view.employees';
  static const reportViewProjects = 'report.view.projects';
  static const reportProjectsSubtitle = 'report.projects.subtitle';
  static const reportProjectsSearch = 'report.projects.search';
  static const reportTotalProjects = 'report.total.projects';
  static const reportColumnProject = 'report.column.project';
  static const reportColumnEmployees = 'report.column.employees';
  static const reportColumnTrips = 'report.column.trips';
  static const reportColumnDays = 'report.column.days';
  static const reportProjectsNoMatch = 'report.projects.noMatch';
  static const reportProjectsEmptyTitle = 'report.projects.empty.title';
  static const reportProjectsEmptyText = 'report.projects.empty.text';
  static const reportFileSapNumber = 'report.file.sapNumber';
  static const reportFileProject = 'report.file.project';
  static const reportFilePlace = 'report.file.place';
  static const reportFileEmployees = 'report.file.employees';
  static const reportProjects = 'report.projects';

  // Locations (Figma HR / Locations 1465:2 to 1465:846)
  static const navLocations = 'nav.locations';
  static const locationsTitle = 'locations.title';
  static const locationsSubtitle = 'locations.subtitle';
  static const locationsSearch = 'locations.search';
  static const locationsFilterAll = 'locations.filter.all';
  static const locationsColumnLocation = 'locations.column.location';
  static const locationsColumnAddress = 'locations.column.address';
  static const locationsColumnArea = 'locations.column.area';
  static const locationsColumnStatus = 'locations.column.status';
  static const locationsCount = 'locations.count';
  static const locationsLoading = 'locations.loading';
  static const locationsLoadFailed = 'locations.loadFailed';
  static const locationsEmptyTitle = 'locations.empty.title';
  static const locationsEmptyText = 'locations.empty.text';
  static const locationAdd = 'location.add';
  static const locationSave = 'location.save';
  // Locations V2 (Figma 1542:153, 1542:322, 1543:114, 1543:216).
  static const locationActiveSubtitle = 'location.active.subtitle';
  static const locationInactiveNote = 'location.inactive.note';
  static const locationsNoMatchTitle = 'locations.noMatch.title';
  static const locationsNoMatchText = 'locations.noMatch.text';
  static const locationsNoInactiveTitle = 'locations.noInactive.title';
  static const locationsNoInactiveText = 'locations.noInactive.text';
  static const locationsNoActiveTitle = 'locations.noActive.title';
  static const locationsNoActiveText = 'locations.noActive.text';
  static const locationAddTitle = 'location.add.title';
  static const locationAddSubtitle = 'location.add.subtitle';
  static const locationFieldName = 'location.field.name';
  static const locationFieldNameHint = 'location.field.name.hint';
  static const locationFieldStreet = 'location.field.street';
  static const locationFieldNumber = 'location.field.number';
  static const locationFieldBox = 'location.field.box';
  static const locationFieldPostcode = 'location.field.postcode';
  static const locationFieldCity = 'location.field.city';
  static const locationArea = 'location.area';
  static const locationAreaValue = 'location.area.value';
  static const locationAreaHint = 'location.area.hint';
  static const locationMapDrag = 'location.map.drag';
  static const locationMapPlace = 'location.map.place';
  static const locationMapNotSetUp = 'location.map.notSetUp';
  static const locationErrorName = 'location.error.name';
  static const locationErrorNameDuplicate = 'location.error.nameDuplicate';
  static const locationErrorStreet = 'location.error.street';
  static const locationDeactivate = 'location.deactivate';
  static const locationReactivate = 'location.reactivate';
  static const locationDeactivateTitle = 'location.deactivate.title';
  static const locationDeactivateText = 'location.deactivate.text';
  static const locationAdded = 'location.added';
  static const locationUpdated = 'location.updated';
  static const locationDeactivated = 'location.deactivated';
  static const locationReactivated = 'location.reactivated';

  // Employees V2 (Figma 1531:2, an employee 1531:259 / 1531:459).
  static const employeeCount = 'employee.count';
  static const employeeFilterAll = 'employee.filter.all';
  static const employeeNotSetUp = 'employee.status.notSetUp';
  static const employeeSetUp = 'employee.status.setUp';
  static const employeeLoading = 'employee.loading';
  static const employeeFactCompanies = 'employee.fact.companies';
  static const employeeFactType = 'employee.fact.type';
  static const employeeFactSchedule = 'employee.fact.schedule';
  static const employeeFactPhone = 'employee.fact.phone';
  static const employeeFactAccount = 'employee.fact.account';
  static const employeeAssignments = 'employee.assignments';
  static const employeeResetAccess = 'employee.resetAccess';
  static const employeeShowSetUpQr = 'employee.showSetUpQr';
  static const employeeShowRecoveryQr = 'employee.showRecoveryQr';
  static const employeeClose = 'employee.close';

  // Deactivate / Reactivate (Figma 1534:366, 1534:188). Argument: `{name}`.
  static const employeeDeactivate = 'employee.deactivate';
  static const employeeReactivate = 'employee.reactivate';
  static const employeeDeactivateTitle = 'employee.deactivate.title';
  static const employeeDeactivateText = 'employee.deactivate.text';
  static const employeeDeactivated = 'employee.deactivated';
  static const employeeReactivated = 'employee.reactivated';
  static const employeeInactiveNote = 'employee.inactive.note';
  static const employeeResetAccessRefused = 'employee.resetAccess.refused';
}

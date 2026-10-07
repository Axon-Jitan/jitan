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
  static const employeeOnboardingShowQr = 'employee.onboarding.showQr';
  static const employeeQrTitle = 'employee.qr.title';

  /// Arguments: `{name}`, `{company}`.
  static const employeeQrSubtitle = 'employee.qr.subtitle';
  static const employeeQrLoading = 'employee.qr.loading';
  static const employeeQrReady = 'employee.qr.ready';

  /// Argument: `{name}` (first name).
  static const employeeQrInstruction = 'employee.qr.instruction';

  /// Argument: `{name}`.
  static const employeeQrSemantics = 'employee.qr.semantics';
  static const employeeQrPersonalTitle = 'employee.qr.personalTitle';

  /// Argument: `{name}` (first name).
  static const employeeQrTerminalInstruction = 'employee.qr.terminalInstruction';
}

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
}

/// User-facing text for the HR/Admin app.
///
/// DEV TEMPORARY (ENGINEERING_RULES §0), to be replaced by I18N-01
/// (docs/BACKLOG.md): Jitan's UI text comes only from `tblTranslation`, but
/// no translation endpoint exists yet, so [_text] reads this hardcoded
/// English map. Each entry is keyed by a stable meaning-based key, so the
/// migration replaces [_text] and deletes the map. English fallback then
/// comes from the database's English bundle, not from here.
abstract final class AdminStrings {
  static String get appTitle => _text('admin.app.title');

  // Companies
  static String get companiesNav => _text('admin.nav.companies');
  static String get companiesTitle => _text('admin.companies.title');
  static String get companiesSubtitle => _text('admin.companies.subtitle');
  static String get companiesSearchHint => _text('admin.companies.search.hint');
  static String get columnCompany => _text('admin.companies.column.company');
  static String get columnEmployees => _text('admin.companies.column.employees');
  static String get columnLocations => _text('admin.companies.column.locations');
  static String get columnStatus => _text('admin.companies.column.status');
  static String get columnLastUpdated => _text('admin.companies.column.lastUpdated');
  static String get statusActive => _text('admin.status.active');
  static String get statusInactive => _text('admin.status.inactive');
  static String get valueUnavailable => _text('admin.value.unavailable');
  static String get locationsUnavailableHint => _text('admin.companies.locations.unavailable');
  static String get lastUpdatedNever => _text('admin.companies.lastUpdated.never');
  static String get companiesLoading => _text('admin.companies.loading');
  static String get companiesEmptyTitle => _text('admin.companies.empty.title');
  static String get companiesEmptyMessage => _text('admin.companies.empty.message');
  static String get companiesNoMatchTitle => _text('admin.companies.noMatch.title');
  static String companiesNoMatchMessage(String search) =>
      _text('admin.companies.noMatch.message').replaceAll('{search}', search);

  // Relative dates
  static String get today => _text('common.date.today');
  static String get yesterday => _text('common.date.yesterday');
  static String daysAgo(int n) => _plural('common.date.daysAgo', n);
  static String weeksAgo(int n) => _plural('common.date.weeksAgo', n);
  static String monthsAgo(int n) => _plural('common.date.monthsAgo', n);
  static String yearsAgo(int n) => _plural('common.date.yearsAgo', n);

  // Errors
  static String get retry => _text('common.action.retry');
  static String get errorNetworkTitle => _text('common.error.network.title');
  static String get errorNetworkMessage => _text('common.error.network.message');
  static String get errorUnauthenticatedTitle => _text('common.error.unauthenticated.title');
  static String get errorUnauthenticatedMessage => _text('common.error.unauthenticated.message');
  static String get errorForbiddenTitle => _text('common.error.forbidden.title');
  static String get errorForbiddenMessage => _text('common.error.forbidden.message');
  static String get errorDatabaseTitle => _text('common.error.database.title');
  static String get errorDatabaseMessage => _text('common.error.database.message');
  static String get errorUnexpectedTitle => _text('common.error.unexpected.title');
  static String get errorUnexpectedMessage => _text('common.error.unexpected.message');

  // Startup
  static String get configErrorTitle => _text('admin.config.error.title');
  static String get configErrorMessage => _text('admin.config.error.message');

  static String _text(String key) {
    final value = _englishFallback[key];
    assert(value != null, 'Missing text for "$key".');
    return value ?? key;
  }

  static String _plural(String key, int n) =>
      _text(n == 1 ? '$key.one' : '$key.other').replaceAll('{n}', '$n');

  static const _englishFallback = {
    'admin.app.title': 'Jitan Admin',
    'admin.nav.companies': 'Companies',
    'admin.companies.title': 'Companies',
    'admin.companies.subtitle': 'View and manage companies in Jitan.',
    'admin.companies.search.hint': 'Search companies',
    'admin.companies.column.company': 'Company',
    'admin.companies.column.employees': 'Employees',
    'admin.companies.column.locations': 'Locations',
    'admin.companies.column.status': 'Status',
    'admin.companies.column.lastUpdated': 'Last updated',
    'admin.status.active': 'Active',
    'admin.status.inactive': 'Inactive',
    'admin.value.unavailable': '—',
    'admin.companies.locations.unavailable': 'Location counts are not available yet.',
    'admin.companies.lastUpdated.never': '—',
    'admin.companies.loading': 'Loading companies…',
    'admin.companies.empty.title': 'No companies yet',
    'admin.companies.empty.message': 'Companies added to Jitan will appear here.',
    'admin.companies.noMatch.title': 'No matching companies',
    'admin.companies.noMatch.message': 'No company name contains “{search}”.',
    'common.date.today': 'Today',
    'common.date.yesterday': 'Yesterday',
    'common.date.daysAgo.one': '{n} day ago',
    'common.date.daysAgo.other': '{n} days ago',
    'common.date.weeksAgo.one': '{n} week ago',
    'common.date.weeksAgo.other': '{n} weeks ago',
    'common.date.monthsAgo.one': '{n} month ago',
    'common.date.monthsAgo.other': '{n} months ago',
    'common.date.yearsAgo.one': '{n} year ago',
    'common.date.yearsAgo.other': '{n} years ago',
    'common.action.retry': 'Try again',
    'common.error.network.title': 'Can’t reach Jitan',
    'common.error.network.message': 'Check your connection and try again.',
    'common.error.unauthenticated.title': 'You’re not signed in',
    'common.error.unauthenticated.message': 'Sign in again to continue.',
    'common.error.forbidden.title': 'No access',
    'common.error.forbidden.message': 'Your account doesn’t have access to this page.',
    'common.error.database.title': 'Jitan is temporarily unavailable',
    'common.error.database.message': 'Please try again in a moment.',
    'common.error.unexpected.title': 'Something went wrong',
    'common.error.unexpected.message': 'Try again. If it keeps happening, contact your administrator.',
    'admin.config.error.title': 'Jitan Admin is not configured',
    'admin.config.error.message':
        'The API address is missing. Build or run with --dart-define=JITAN_API_BASE_URL=<url>.',
  };
}

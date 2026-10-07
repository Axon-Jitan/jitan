/// The built-in English UI texts: Jitan's guaranteed default and final
/// fallback language (I18N-01).
///
/// **This is the one central source of English copy.** Screens never contain
/// English literals; they call `t(key)` and the translation service resolves
/// the key here when no database translation applies. English therefore
/// works with no API, database or network.
///
/// Other languages come from `tblTranslation` and fall back to this map key
/// by key.
///
/// Keys describe meaning, not copy. Plural keys come in `<base>.one` and
/// `<base>.other` pairs. Placeholders are `{name}`. Every key used in code
/// must exist here (enforced by a test in each app).
const builtInEnglish = <String, String>{
  // ── Common ────────────────────────────────────────────────────────────
  'common.retry': 'Try again',
  'common.value.unavailable': '—',
  'common.status.active': 'Active',
  'common.status.inactive': 'Inactive',

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

  // ── HR/Admin app ──────────────────────────────────────────────────────
  'app.admin.title': 'Jitan Admin',
  'app.config.error.title': 'Jitan Admin is not configured',
  'app.config.error.message':
      'The API address is missing. Build or run with --dart-define=JITAN_API_BASE_URL=<url>.',
  'nav.companies': 'Companies',

  // ── Companies ─────────────────────────────────────────────────────────
  'company.title': 'Companies',
  'company.list.subtitle': 'View and manage companies in Jitan.',
  'company.search': 'Search companies',
  'company.list.loading': 'Loading companies…',
  'company.column.name': 'Company',
  'company.column.employees': 'Employees',
  'company.column.locations': 'Locations',
  'company.column.status': 'Status',
  'company.column.lastUpdated': 'Last updated',
  'company.locations.unavailable': 'Location counts are not available yet.',
  'company.empty.title': 'No companies yet',
  'company.empty.message': 'Companies added to Jitan will appear here.',
  'company.noMatch.title': 'No matching companies',
  'company.noMatch.message': 'No company name contains “{search}”.',
};

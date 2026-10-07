// DEVELOPMENT SEED DATA, not a translation source.
//
// English rows that `tool/dev_seed.dart` inserts into a dev database's
// tblTranslation when they are missing, so the apps show text instead of
// keys during development. The apps never read this file: at runtime every
// text comes from tblTranslation through GET /translations (I18N-01).
//
// Production translation content is managed in the database itself; how it
// gets there is an open I18N-01 point (docs/BACKLOG.md).
//
// Keep keys in sync with CommonTextKeys (packages/jitan_core) and
// AdminTextKeys (apps/admin_web).

const devEnglishTranslations = <String, String>{
  // app / navigation
  'app.admin.title': 'Jitan Admin',
  'app.config.error.title': 'Jitan Admin is not configured',
  'app.config.error.message': 'The API address is missing. Build or run with --dart-define=JITAN_API_BASE_URL=<url>.',
  'nav.companies': 'Companies',

  // company list
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

  // common
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
};

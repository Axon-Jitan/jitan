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
  'common.error.notFound.title': 'Not found',
  'common.error.notFound.message': 'It may have been removed. Reload to see the current data.',
  'common.error.unexpected.title': 'Something went wrong',
  'common.error.unexpected.message': 'Try again. If it keeps happening, contact your administrator.',

  // ── HR/Admin app ──────────────────────────────────────────────────────
  'app.admin.title': 'Jitan Admin',
  'app.config.error.title': 'Jitan Admin is not configured',
  'app.config.error.message':
      'The API address is missing. Build or run with --dart-define=JITAN_API_BASE_URL=<url>.',
  'nav.companies': 'Companies',
  'nav.employees': 'Employees',

  // Development-only tools (visible only in builds with JITAN_DEV_TOOLS=true)
  'dev.companySelector.label': 'DEV · Current company',
  'dev.companySelector.placeholder': 'Choose a company',
  'dev.companySelector.loadFailed': 'Companies could not be loaded.',

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

  // ── Employees ─────────────────────────────────────────────────────────
  'employee.title': 'Employees',
  'employee.list.subtitle': 'Manage employees for the selected company and track onboarding.',
  'employee.search': 'Search name or employee code',
  'employee.list.loading': 'Loading employees…',
  'employee.column.name': 'Employee',
  'employee.column.code': 'Code',
  'employee.column.type': 'Type',
  'employee.column.location': 'Location',
  'employee.column.onboarding': 'Onboarding',
  'employee.column.status': 'Status',
  'employee.location.unavailable': 'Employee locations are not available yet.',
  'employee.onboarding.unavailable': 'Onboarding status is not available yet.',
  'employee.empty.title': 'No employees yet',
  'employee.empty.message': 'Employees of {company} will appear here.',
  'employee.noMatch.title': 'No matching employees',
  'employee.noMatch.message': 'No employee name or code contains “{search}”.',
  'employee.noCompany.title': 'No company selected',
  'employee.noCompany.message': 'Select a company to see its employees.',

  // Add employee (EMP-02)
  'employee.add.action': 'Add employee',
  'employee.add.title': 'Add employee',
  'employee.add.subtitle': 'Create the employee record.',
  'employee.add.submit': 'Create employee',
  'employee.add.success': '{name} was added.',
  'employee.field.firstName': 'First name',
  'employee.field.lastName': 'Last name',
  'employee.field.code': 'Employee code',
  'employee.field.type': 'Employee type',
  'employee.field.type.none': 'No type',
  'employee.field.type.loadFailed': 'Employee types could not be loaded. You can add a type later.',
  'employee.field.phone': 'Phone number',
  'employee.field.phone.hint': 'Optional',
  'employee.field.error.required': 'Required.',
  'employee.field.error.duplicateCode': 'This employee code is already in use.',
  'employee.field.error.invalidType': 'This employee type is no longer available.',
  'employee.field.error.tooLong': 'One of the values is too long.',

  // Employee details (EMP-03)
  'employee.details.title': 'Employee details',
  'employee.details.subtitle': '{company} · Employee code {code}',
  'employee.details.loading': 'Loading employee…',
  'employee.field.location': 'Location',
  'employee.field.account': 'Account',
  'employee.field.status': 'Status',
  'employee.account.unavailable': 'Account activation status is not available yet.',

  // Onboarding QR (EMP-08)
  'employee.onboarding.title': 'Onboarding',
  'employee.onboarding.text': 'Generate a personal QR for this employee to scan in Jitan.',
  'employee.onboarding.action': 'Generate onboarding QR',
  'employee.qr.title': 'Onboarding QR',
  'employee.qr.subtitle': '{name} · {company}',
  'employee.qr.loading': 'Preparing the QR…',
  'employee.qr.ready': 'READY TO SCAN',
  'employee.qr.instruction': 'Ask {name} to open Jitan and scan this QR.',
  'employee.qr.semantics': 'Onboarding QR code for {name}',
};

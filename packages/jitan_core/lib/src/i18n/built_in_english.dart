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
  'common.back': 'Back',
  'common.continue': 'Continue',
  'common.cancel': 'Cancel',
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
  'app.config.error.message': 'The API address is missing. Build or run with --dart-define=JITAN_API_BASE_URL=<url>.',
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
  'employee.onboarding.activated': 'Activated',
  'employee.onboarding.notActivated': 'Not activated',
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

  // Onboarding QR (EMP-08)
  'employee.onboarding.title': 'Onboarding',
  'employee.onboarding.text': 'Generate a personal QR for this employee to scan in Jitan.',
  'employee.onboarding.action': 'Generate onboarding QR',
  'employee.onboarding.completedText':
      'Onboarding is complete. This is now the employee’s personal QR for Jitan Terminal.',
  'employee.onboarding.showQr': 'Show personal QR',
  'employee.qr.title': 'Onboarding QR',
  'employee.qr.subtitle': '{name} · {company}',
  'employee.qr.loading': 'Preparing the QR…',
  'employee.qr.ready': 'READY TO SCAN',
  'employee.qr.instruction': 'Ask {name} to open Jitan and scan this QR.',
  'employee.qr.semantics': 'Onboarding QR code for {name}',
  'employee.qr.personalTitle': 'Personal QR',
  'employee.qr.terminalInstruction': '{name} scans this QR at a Jitan Terminal to check in and out.',

  // ── Employee app ──────────────────────────────────────────────────────
  'app.employee.title': 'Jitan',
  'app.employee.config.error.title': 'Jitan is not configured',
  'app.employee.config.error.message': 'The API address is missing. Build or run with --dart-define=JITAN_API_BASE_URL=<url>.',

  // Onboarding (Figma 01 — Employee App, "Onboarding / …")
  'onboarding.welcome.eyebrow': 'YOUR WORKDAY, SIMPLIFIED',
  'onboarding.welcome.title': 'Time tracking,\nwithout the tracking.',
  'onboarding.welcome.text': 'Jitan builds your workday automatically and only asks when something needs your attention.',
  'onboarding.welcome.action': 'Get started',

  'onboarding.join.title': 'Join your workplace',
  'onboarding.join.text': 'Scan the personal Jitan QR that HR/Admin shows you.',
  'onboarding.join.hint': 'Point your camera at your Jitan QR',
  'onboarding.join.action': 'Scan QR',

  'onboarding.scan.title': 'Scan your Jitan QR',
  'onboarding.scan.cameraUnavailable': 'Jitan can’t use the camera. Allow camera access in Settings and try again.',

  'onboarding.confirm.title': 'Is this you?',
  'onboarding.confirm.action': 'Yes, this is me',
  'onboarding.confirm.notYou': 'Not you?',
  'onboarding.confirm.goBack': 'Go back',

  'onboarding.language.title': 'Choose your language',
  'onboarding.language.text': 'Jitan will use this language. You can change it later in Profile.',
  'onboarding.language.loadFailed': 'Other languages couldn’t be loaded. You can continue in English.',
  'onboarding.language.invalid': 'This language is no longer available. Choose another one.',
  'onboarding.language.english': 'English',

  'onboarding.method.title': 'How do you want to\nregister your time?',
  'onboarding.method.text': 'Choose what works best for you. You can change this later in Settings.',
  'onboarding.method.automatic.title': 'Automatic registration',
  'onboarding.method.automatic.text': 'Jitan recognises when you arrive at or leave approved workplaces. Most days, you don’t need to do anything.',
  'onboarding.method.manual.title': 'QR / manual registration',
  'onboarding.method.manual.text': 'Use your QR code at the Jitan Terminal, or enter your working time manually when needed.',
  'onboarding.method.note': 'Automatic registration requires location permission.',

  'onboarding.permissions.title': 'Finish your setup.',
  'onboarding.permissions.text': 'We’ll only ask for the permissions your chosen setup needs.',
  'onboarding.permissions.location.title': 'Location',
  'onboarding.permissions.location.text': 'Required only if you chose automatic registration.',
  'onboarding.permissions.notifications.title': 'Notifications',
  'onboarding.permissions.notifications.text': 'Only when your workday needs confirmation.',
  'onboarding.permissions.privacy.title': 'Built for work registration',
  'onboarding.permissions.privacy.text': 'Jitan uses workplace signals to build your workday. Your company controls its registration policy.',

  'onboarding.password.title': 'Set your password',
  'onboarding.password.text': 'Use this password if you need to sign in to Jitan on the web without your QR code.',
  'onboarding.password.label': 'Password',
  'onboarding.password.hint': 'At least 8 characters (12+ recommended)',
  'onboarding.password.confirm.label': 'Confirm password',
  'onboarding.password.confirm.hint': 'Re-enter your password',
  'onboarding.password.show': 'Show password',
  'onboarding.password.hide': 'Hide password',
  'onboarding.password.error.tooShort': 'Use at least 8 characters.',
  'onboarding.password.error.tooLong': 'Use at most 256 characters.',
  'onboarding.password.error.mismatch': 'Passwords don’t match.',
  'onboarding.password.error.rejected': 'This password can’t be used. Choose another one.',
  'onboarding.password.note.title': 'Your password is private',
  'onboarding.password.note.text': 'HR and Admin cannot see or set your password. You can change it later from Profile.',
  'onboarding.step': '{n} of {total}',

  'onboarding.ready.badge': 'SETUP COMPLETE',
  'onboarding.ready.title': 'You’re ready.',
  'onboarding.ready.text': 'Go to work as usual. Jitan handles the time.',
  'onboarding.ready.workplace': 'Workplace connected',
  'onboarding.ready.method': 'Registration method set',
  'onboarding.ready.permissions': 'Required permissions configured',
  'onboarding.ready.locationMissing': 'Allow location in Settings to use automatic registration',
  'onboarding.ready.action': 'Start Jitan',

  // Onboarding errors (Figma "Onboarding Error / …")
  'onboarding.error.invalidQr.title': 'QR not recognised',
  'onboarding.error.invalidQr.text': 'This isn’t a valid Jitan onboarding QR.',
  'onboarding.error.invalidQr.helpTitle': 'What to do',
  'onboarding.error.invalidQr.help': 'Make sure the full QR is visible and try scanning again. Jitan will not reveal whether an employee exists.',
  'onboarding.error.alreadyActivated.title': 'Account already activated',
  'onboarding.error.alreadyActivated.text': 'This employee has already completed Jitan onboarding.',
  'onboarding.error.alreadyActivated.helpTitle': 'Onboarding cannot restart',
  'onboarding.error.alreadyActivated.help': 'Use your employee code and password to sign in, or contact HR/Admin if you can’t access the account.',
  'onboarding.error.unavailable.title': 'Account can’t be activated',
  'onboarding.error.unavailable.text': 'This account is currently unavailable.',
  'onboarding.error.unavailable.helpTitle': 'Contact HR/Admin',
  'onboarding.error.unavailable.help': 'The employee account may be inactive or no longer available in Jitan.',
  'onboarding.error.activatedElsewhere.title': 'Account was just activated',
  'onboarding.error.activatedElsewhere.text': 'Another device completed onboarding before this one.',
  'onboarding.error.activatedElsewhere.helpTitle': 'Only one device can finish onboarding',
  'onboarding.error.activatedElsewhere.help': 'Your account is now active. Sign in normally on this device if you want to use Jitan here.',
  'onboarding.error.network.title': 'Couldn’t finish setup',
  'onboarding.error.network.text': 'Jitan couldn’t confirm the final onboarding step.',
  'onboarding.error.network.helpTitle': 'Your progress is safe',
  'onboarding.error.network.help': 'Check your connection and try again. Jitan will verify whether onboarding already completed before making any changes.',
  'onboarding.error.server.title': 'Jitan is temporarily unavailable',
  'onboarding.error.server.text': 'We can’t reach the Jitan service right now.',
  'onboarding.error.server.helpTitle': 'Please try again shortly',
  'onboarding.error.server.help': 'No onboarding changes will be made until the server confirms the request.',
  'onboarding.error.sessionRecovery.title': 'Setup completed, sign-in pending',
  'onboarding.error.sessionRecovery.text': 'Your account setup completed, but Jitan could not finish signing this device in.',
  'onboarding.error.sessionRecovery.helpTitle': 'Your account is already activated',
  'onboarding.error.sessionRecovery.help': 'Jitan will retry session creation without repeating onboarding or changing your password.',
  'onboarding.error.sessionRecovery.action': 'Retry sign-in',

  // Home (placeholder until the Today screens)
  'home.greeting': 'Hello, {name}',
  'home.greetingNoName': 'Hello',
  'home.text': 'You’re signed in on this device. Your workday will appear here.',
};

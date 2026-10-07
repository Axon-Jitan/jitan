/// `tblTranslation.translationUIName` keys shared by every Jitan app.
///
/// Keys only. English texts live in `builtInEnglish`; other languages in
/// `tblTranslation`. Keys describe meaning, not copy. Plural keys are bases:
/// the texts are `<base>.one` and `<base>.other` (see `Translations.plural`).
abstract final class CommonTextKeys {
  static const retry = 'common.retry';
  static const valueUnavailable = 'common.value.unavailable';

  static const statusActive = 'common.status.active';
  static const statusInactive = 'common.status.inactive';

  static const dateToday = 'common.date.today';
  static const dateYesterday = 'common.date.yesterday';
  static const dateDaysAgo = 'common.date.daysAgo';
  static const dateWeeksAgo = 'common.date.weeksAgo';
  static const dateMonthsAgo = 'common.date.monthsAgo';
  static const dateYearsAgo = 'common.date.yearsAgo';

  static const errorNetworkTitle = 'common.error.network.title';
  static const errorNetworkMessage = 'common.error.network.message';
  static const errorUnauthenticatedTitle = 'common.error.unauthenticated.title';
  static const errorUnauthenticatedMessage = 'common.error.unauthenticated.message';
  static const errorForbiddenTitle = 'common.error.forbidden.title';
  static const errorForbiddenMessage = 'common.error.forbidden.message';
  static const errorDatabaseTitle = 'common.error.database.title';
  static const errorDatabaseMessage = 'common.error.database.message';
  static const errorUnexpectedTitle = 'common.error.unexpected.title';
  static const errorUnexpectedMessage = 'common.error.unexpected.message';
}

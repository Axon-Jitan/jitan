import '../l10n/admin_text_keys.dart';

/// What a correction window did; the list reloads after any of them, and
/// all but [partlySaved] are confirmed by "Correction saved" (272:547).
enum TimeCorrectionOutcome {
  corrected(AdminTextKeys.timeSavedText),
  resolvedStart(AdminTextKeys.timeSavedStart),
  resolvedFinish(AdminTextKeys.timeSavedFinish),
  nonWork(AdminTextKeys.timeSavedNonWork),
  approved(AdminTextKeys.timeSavedApproved),
  rejected(AdminTextKeys.timeSavedRejected),

  /// Correct time saved the start, then the finish failed and HR closed the
  /// window: the start counts, so the list reloads, without "saved".
  partlySaved(null);

  const TimeCorrectionOutcome(this.messageKey);

  final String? messageKey;
}

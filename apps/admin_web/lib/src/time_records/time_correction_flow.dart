import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'correct_time_dialog.dart';
import 'resolve_missing_dialog.dart';
import 'review_correction_dialog.dart';
import 'time_correction_outcome.dart';
import 'time_record_text.dart';

/// Which correction window HR opens for a day.
enum TimeCorrectionStep {
  /// "Correct time record" (160:220): change or add the start and finish.
  correct,

  /// "Resolve missing start/finish" (272:457): set it, or mark non-work.
  resolve,

  /// "Review correction" (160:338): the employee's correction (D31).
  review;

  /// The table's action for [day]: Fix, Review, or `null` for View.
  static TimeCorrectionStep? forRow(TimeRecordDay day) => switch (day.status) {
    TimeRecordStatus.missingStart || TimeRecordStatus.missingFinish => resolve,
    TimeRecordStatus.noRegistration => correct,
    TimeRecordStatus.pendingReview => review,
    _ => null,
  };
}

/// Opens [step] for [day] in [companyId] and, once the server confirmed,
/// "Correction saved" (272:547). Returns `true` when anything was saved, so
/// the list reloads.
Future<bool> showTimeCorrection(
  BuildContext context, {
  required TimeRecordsApi api,
  required TimeRecordDay day,
  required int companyId,
  required TimeCorrectionStep step,
}) async {
  final outcome = await showJitanModal<TimeCorrectionOutcome>(
    context,
    // A tap beside the window must not lose what HR typed, or hide a save.
    barrierDismissible: false,
    builder: (_) => switch (step) {
      TimeCorrectionStep.correct => CorrectTimeDialog(api: api, day: day, companyId: companyId),
      TimeCorrectionStep.resolve => ResolveMissingDialog(api: api, day: day, companyId: companyId),
      TimeCorrectionStep.review => ReviewCorrectionDialog(api: api, day: day, companyId: companyId),
    },
  );
  if (outcome == null) return false;
  if (outcome.messageKey case final messageKey? when context.mounted) {
    await showJitanModal<void>(
      context,
      builder: (context) => JitanSuccessModal(
        title: context.t(AdminTextKeys.timeSavedTitle),
        subtitle: '${TimeRecordText.name(day)} · ${TimeRecordText.longDate(context, day.date)}',
        message: context.t(messageKey),
        buttonLabel: context.t(AdminTextKeys.timeSavedBack),
        onDone: () => Navigator.of(context).pop(),
      ),
    );
  }
  return true;
}

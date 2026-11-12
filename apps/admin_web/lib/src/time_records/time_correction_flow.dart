import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'correct_time_dialog.dart';
import 'resolve_missing_dialog.dart';
import 'review_correction_dialog.dart';
import 'time_correction_outcome.dart';
import 'time_record_text.dart';

/// Which correction window HR opens for a day.
enum TimeCorrectionStep {
  /// "Correct time" (`1566:788`): change or add the start and finish.
  correct,

  /// "Missing start/finish" (`1566:272`): add it, or not a work day.
  resolve,

  /// "Review correction" (`1566:1040`): the employee's correction (D31).
  review;

  /// The list's action for [day]: Fix, Review, or `null` (it opens the day).
  static TimeCorrectionStep? forRow(TimeRecordDay day) => switch (day.status) {
    TimeRecordStatus.missingStart || TimeRecordStatus.missingFinish => resolve,
    TimeRecordStatus.noRegistration => correct,
    TimeRecordStatus.pendingReview => review,
    _ => null,
  };
}

/// Opens [step] for [day] in [companyId] and, once the server confirmed,
/// says what was saved in a toast. Returns `true` when anything was saved, so
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
    showJitanToast(context, context.t(messageKey, args: {'name': TimeRecordText.name(day)}));
  }
  return true;
}

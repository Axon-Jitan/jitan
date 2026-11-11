import 'package:jitan_models/jitan_models.dart';

/// What Time records' status filter lets through: one status, or every day
/// to review (as the Dashboard and Reports count them).
class TimeRecordStatusFilter {
  const TimeRecordStatusFilter.only(TimeRecordStatus this.status);

  const TimeRecordStatusFilter._toReview() : status = null;

  /// Missing start or finish, waiting for HR, or no registration.
  static const toReview = TimeRecordStatusFilter._toReview();

  static const _review = {
    TimeRecordStatus.missingStart,
    TimeRecordStatus.missingFinish,
    TimeRecordStatus.pendingReview,
    TimeRecordStatus.noRegistration,
  };

  /// `null` for [toReview].
  final TimeRecordStatus? status;

  bool lets(TimeRecordDay day) => status == null ? _review.contains(day.status) : day.status == status;

  /// In a link: a status's wire name, or `to_review`.
  String get wireName => status?.wireName ?? 'to_review';

  /// What [wireName] wrote; `null` for anything else.
  static TimeRecordStatusFilter? fromWire(String? value) {
    if (value == null) return null;
    if (value == 'to_review') return toReview;
    for (final status in TimeRecordStatus.values) {
      if (status.wireName == value) return TimeRecordStatusFilter.only(status);
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is TimeRecordStatusFilter && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

import 'package:jitan_models/jitan_models.dart';

enum _Kind { only, toReview, finished }

/// What Time records' status filter lets through: one status, every day to
/// review (as the Dashboard and Reports count them), or every finished day
/// (as the Dashboard's Today counts them).
class TimeRecordStatusFilter {
  const TimeRecordStatusFilter.only(TimeRecordStatus this.status) : _kind = _Kind.only;

  const TimeRecordStatusFilter._(this._kind) : status = null;

  /// Missing start or finish, waiting for HR, or no registration.
  static const toReview = TimeRecordStatusFilter._(_Kind.toReview);

  /// A finish is registered, whatever else the day has.
  static const finished = TimeRecordStatusFilter._(_Kind.finished);

  static const _review = {
    TimeRecordStatus.missingStart,
    TimeRecordStatus.missingFinish,
    TimeRecordStatus.pendingReview,
    TimeRecordStatus.noRegistration,
  };

  /// `null` unless one status.
  final TimeRecordStatus? status;
  final _Kind _kind;

  bool lets(TimeRecordDay day) => switch (_kind) {
    _Kind.only => day.status == status,
    _Kind.toReview => _review.contains(day.status),
    _Kind.finished => day.finish != null,
  };

  /// In a link: a status's wire name, `to_review` or `finished`.
  String get wireName => switch (_kind) {
    _Kind.only => status!.wireName,
    _Kind.toReview => 'to_review',
    _Kind.finished => 'finished',
  };

  /// What [wireName] wrote; `null` for anything else.
  static TimeRecordStatusFilter? fromWire(String? value) {
    if (value == null) return null;
    if (value == 'to_review') return toReview;
    if (value == 'finished') return finished;
    for (final status in TimeRecordStatus.values) {
      if (status.wireName == value) return TimeRecordStatusFilter.only(status);
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is TimeRecordStatusFilter && other._kind == _kind && other.status == status;

  @override
  int get hashCode => Object.hash(_kind, status);
}

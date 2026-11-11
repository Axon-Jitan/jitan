import 'package:jitan_models/jitan_models.dart';

enum _Kind { only, toReview, finished, attendance }

/// What Time records' status filter lets through: one status, every day to
/// review (as the Dashboard and Reports count them), every finished day (the
/// Dashboard's Today), or the finished days on time, late or left early (the
/// Dashboard's Attendance).
class TimeRecordStatusFilter {
  const TimeRecordStatusFilter.only(TimeRecordStatus this.status) : _kind = _Kind.only, attendance = null;

  const TimeRecordStatusFilter.attended(DayAttendance this.attendance) : _kind = _Kind.attendance, status = null;

  const TimeRecordStatusFilter._(this._kind) : status = null, attendance = null;

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

  /// `null` unless on time, late or left early.
  final DayAttendance? attendance;
  final _Kind _kind;

  bool lets(TimeRecordDay day) => switch (_kind) {
    _Kind.only => day.status == status,
    _Kind.toReview => _review.contains(day.status),
    _Kind.finished => day.finish != null,
    _Kind.attendance => day.attendance == attendance,
  };

  /// In a link: a status's or an attendance's wire name, `to_review` or
  /// `finished`.
  String get wireName => switch (_kind) {
    _Kind.only => status!.wireName,
    _Kind.toReview => 'to_review',
    _Kind.finished => 'finished',
    _Kind.attendance => attendance!.wireName,
  };

  /// What [wireName] wrote; `null` for anything else.
  static TimeRecordStatusFilter? fromWire(String? value) {
    if (value == null) return null;
    if (value == 'to_review') return toReview;
    if (value == 'finished') return finished;
    for (final status in TimeRecordStatus.values) {
      if (status.wireName == value) return TimeRecordStatusFilter.only(status);
    }
    for (final attendance in DayAttendance.values) {
      if (attendance.wireName == value) return TimeRecordStatusFilter.attended(attendance);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is TimeRecordStatusFilter && other._kind == _kind && other.status == status && other.attendance == attendance;

  @override
  int get hashCode => Object.hash(_kind, status, attendance);
}

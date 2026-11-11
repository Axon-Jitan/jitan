import 'package:jitan_api/src/activities/activity_repository.dart';
import 'package:jitan_api/src/activities/trip_kilometres.dart';
import 'package:jitan_api/src/reports/project_report_days.dart';
import 'package:jitan_api/src/time_records/week_plans.dart';
import 'package:jitan_api/src/time_registration/workplace_clock.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

// November in Brussels is UTC+1: 08:00 local is 07:00 UTC.
final _clock = WorkplaceClock('Europe/Brussels');
final _monday = DateTime.utc(2026, 11, 2);

const _workshop = 1; // a workplace, not a project
const _towers = 10;
const _roof = 11;

const _projects = {
  _towers: ProjectSummary(id: _towers, sapNumber: 'P-1057', name: 'Cooling towers', isClientSite: true, isActive: true, placeName: 'Engis'),
  _roof: ProjectSummary(id: _roof, sapNumber: 'P-1071', name: 'Roof repairs', isClientSite: true, isActive: true, placeName: 'Tournai'),
};

const _hanne = EmployeeSummary(id: 7, firstName: 'Hanne', lastName: 'Claes', code: 'CLH', groups: [], isActive: true, isActivated: true);
const _kevin = EmployeeSummary(id: 8, firstName: 'Kevin', lastName: 'De Vos', code: 'KDV', groups: [], isActive: true, isActivated: true);

/// Workplace-local [hhmm] on [date], in UTC.
DateTime _at(String hhmm, [DateTime? date]) {
  final d = date ?? _monday;
  return _clock.utcOf(DateTime(d.year, d.month, d.day, int.parse(hhmm.substring(0, 2)), int.parse(hhmm.substring(3))));
}

TimeRecordTime _time(String hhmm, [DateTime? date]) => TimeRecordTime(
  actualId: 1,
  actual: _at(hhmm, date),
  rounded: _at(hhmm, date),
  method: TimeRecordMethod.geofence,
  enteredByHand: false,
  actualLocal: hhmm,
);

TimeRecordDay _day(
  EmployeeSummary e,
  String? start,
  String? finish, {
  DateTime? date,
  int awayMinutes = 0,
  List<TimeRecordEvent> events = const [],
}) => TimeRecordDay(
  employeeId: e.id,
  employeeCode: e.code,
  date: date ?? _monday,
  status: finish == null ? TimeRecordStatus.missingFinish : TimeRecordStatus.complete,
  start: start == null ? null : _time(start, date),
  finish: finish == null ? null : _time(finish, date),
  awayMinutes: awayMinutes,
  events: events,
);

var _ids = 0;
ActivityRow _row(String kind, String hhmm, int? address, [DateTime? date]) =>
    (id: ++_ids, typeName: 'Activity – $kind', at: _at(hhmm, date), addressId: address);

/// 08:00–16:30 with a break from 12:00 to 12:30, every weekday.
final Map<int, DayPlan> _week = {
  for (var weekday = 1; weekday <= 5; weekday++)
    weekday: (
      start: '08:00',
      finish: '16:30',
      breakStart: '12:00',
      breakFinish: '12:30',
      breakMinutes: 30,
      startMargin: 0,
      finishMargin: 0,
    ),
};

List<ProjectReportProject> _build({
  List<EmployeeSummary> employees = const [_hanne],
  required List<TimeRecordDay> days,
  required Map<int, List<ActivityRow>> activities,
  Map<Trip, int?> metres = const {},
}) => ProjectReportDays.build(
  employees: employees,
  days: days,
  activities: activities,
  plans: {for (final e in employees) e.id: _week},
  projects: _projects,
  metres: metres,
  clock: _clock,
);

void main() {
  test('a whole day on one project adds up to the day’s Worked: start to finish, without the break', () {
    final report = _build(
      days: [_day(_hanne, '08:00', '16:30')],
      activities: {
        _hanne.id: [_row('Client on site', '08:00', _towers)],
      },
    );

    final towers = report.single;
    expect(towers.project.fullName, 'P-1057 Cooling towers');
    expect(towers.workedMinutes, 8 * 60);
    final hanne = towers.employees.single;
    expect((hanne.code, hanne.days, hanne.workedMinutes, hanne.trips), ('CLH', 1, 8 * 60, 0));
  });

  test('a switch splits the day between two projects; time before the first project counts for none', () {
    final report = _build(
      days: [_day(_hanne, '08:00', '16:30')],
      activities: {
        _hanne.id: [
          _row('Work', '08:00', _workshop),
          _row('Client on site', '09:00', _towers),
          _row('Client in-house', '14:00', _roof),
        ],
      },
    );

    final byName = {for (final p in report) p.project.sapNumber: p.workedMinutes};
    // 09:00–14:00 without the 30-minute break; 14:00–16:30.
    expect(byName, {'P-1057': 270, 'P-1071': 150});
    expect(report.first.project.sapNumber, 'P-1057', reason: 'the most worked first');
  });

  test('travel belongs to the project it arrives at, the way back to the project it leaves; never to Worked', () {
    final there = (from: _workshop, to: _towers), back = (from: _towers, to: _workshop);
    final report = _build(
      days: [_day(_hanne, '08:00', '16:30')],
      activities: {
        _hanne.id: [
          _row('Work', '08:00', _workshop),
          _row('Transport', '08:30', _workshop),
          _row('Client on site', '09:20', _towers),
          _row('Transport', '15:40', _towers),
          _row('Work', '16:20', _workshop),
        ],
      },
      metres: {there: 36400, back: 36400},
    );

    final towers = report.single;
    expect(towers.travelMinutes, 50 + 40);
    expect((towers.trips, towers.distanceMetres, towers.tripsWithoutDistance), (2, 72800, 0));
    // 09:20–15:40 without the break.
    expect(towers.workedMinutes, 6 * 60 + 20 - 30);
    expect(towers.employees.single.days, 1);
  });

  test('a trip whose route isn’t known is counted, and said to be left out of the distance', () {
    final report = _build(
      days: [_day(_hanne, '08:00', '16:30')],
      activities: {
        _hanne.id: [
          _row('Work', '08:00', _workshop),
          _row('Transport', '08:30', _workshop),
          _row('Client on site', '09:00', _towers),
        ],
      },
    );

    expect((report.single.trips, report.single.distanceMetres, report.single.tripsWithoutDistance), (1, 0, 1));
  });

  test('a day still waiting (missing finish) is left out until it is fixed', () {
    final report = _build(
      days: [_day(_hanne, '08:00', null)],
      activities: {
        _hanne.id: [_row('Client on site', '08:00', _towers)],
      },
    );

    expect(report, isEmpty);
  });

  test('time away replaces the break, as in the hours report', () {
    final report = _build(
      days: [
        _day(
          _hanne,
          '08:00',
          '16:30',
          awayMinutes: 60,
          events: const [
            TimeRecordEvent(atLocal: '08:00', boundary: RegistrationBoundary.start, kind: TimeRecordEventKind.registered, active: true),
            TimeRecordEvent(atLocal: '11:00', boundary: RegistrationBoundary.finish, kind: TimeRecordEventKind.registered, active: true),
            TimeRecordEvent(atLocal: '12:00', boundary: RegistrationBoundary.start, kind: TimeRecordEventKind.registered, active: true),
            TimeRecordEvent(atLocal: '16:30', boundary: RegistrationBoundary.finish, kind: TimeRecordEventKind.registered, active: true),
          ],
        ),
      ],
      activities: {
        _hanne.id: [_row('Client on site', '08:00', _towers)],
      },
    );

    expect(report.single.workedMinutes, 8 * 60 + 30 - 60);
  });

  test('an activity before the rounded start counts from the start', () {
    final report = _build(
      days: [_day(_hanne, '08:00', '12:00')],
      activities: {
        _hanne.id: [_row('Client on site', '07:40', _towers)],
      },
    );

    expect(report.single.workedMinutes, 4 * 60);
  });

  test('several employees and days: each employee once per project, with their days, the most worked first', () {
    final tuesday = DateTime.utc(2026, 11, 3);
    final report = _build(
      employees: const [_hanne, _kevin],
      days: [
        _day(_hanne, '08:00', '12:00'),
        _day(_hanne, '08:00', '12:00', date: tuesday),
        _day(_kevin, '08:00', '17:30'),
      ],
      activities: {
        _hanne.id: [_row('Client on site', '08:00', _towers), _row('Client on site', '08:00', _towers, tuesday)],
        _kevin.id: [_row('Client on site', '08:00', _towers)],
      },
    );

    final towers = report.single;
    expect(towers.workedMinutes, 4 * 60 * 2 + 9 * 60);
    expect([for (final e in towers.employees) (e.code, e.days, e.workedMinutes)], [('KDV', 1, 540), ('CLH', 2, 480)]);
  });

  test('work without a project, or at a workplace, is in no project', () {
    final report = _build(
      days: [_day(_hanne, '08:00', '16:30')],
      activities: {
        _hanne.id: [_row('Work', '08:00', _workshop), _row('Work', '10:00', null)],
      },
    );

    expect(report, isEmpty);
  });

  test('the type names are the activity rows', () {
    expect(ActivityRepository.transportType, 'Activity – Transport');
  });
}

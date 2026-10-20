import 'package:admin_web/src/l10n/admin_text_keys.dart';
import 'package:admin_web/src/schedules/schedule_form_controller.dart';
import 'package:admin_web/src/schedules/schedule_form_fields.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_models/jitan_models.dart';

import '../support/fake_companies_api.dart' show serverError;
import '../support/fake_schedules_api.dart';

void main() {
  late FakeSchedulesApi api;

  final blue = groupSchedule(
    1,
    'Blue collar',
    work: workDays([1, 2, 3, 4, 5], '08:00', '16:30', tolerance: 10),
    breakDays: breaks([1, 2, 3, 4, 5], '12:00', 30),
  );
  final fresh = groupSchedule(2, 'New group', status: GroupScheduleStatus.noSchedule);
  final mixed = groupSchedule(3, 'Mixed', status: GroupScheduleStatus.noSingleGroupEmployees);
  final groups = [blue, fresh, mixed];

  Future<ScheduleFormController> ready({GroupSchedule? group}) async {
    final c = ScheduleFormController(api, groups: groups, group: group);
    final loading = c.loadOptions();
    api.succeedOptions();
    await loading;
    return c;
  }

  /// A new schedule for "New group", Monday and Friday 07:30–16:00, on the
  /// Working hours & break step (no break length yet).
  Future<ScheduleFormController> filledIn() async {
    final c = await ready();
    c
      ..selectGroup(2)
      ..next()
      ..toggleDay(11)
      ..toggleDay(15)
      ..setStart('07:30')
      ..setFinish('16:00');
    return c;
  }

  setUp(() => api = FakeSchedulesApi());

  test('the steps in order; Continue needs a group and a day; the break is asked with the hours', () async {
    final c = await ready();
    expect((c.step, c.canContinue), (ScheduleStep.group, false));

    c
      ..selectGroup(2)
      ..next();
    expect((c.step, c.canContinue), (ScheduleStep.hours, false), reason: 'no day yet');

    c
      ..toggleDay(11)
      ..setStart('08:00')
      ..setFinish('16:00')
      ..next();
    expect(c.step, ScheduleStep.hours, reason: 'a break is required on the same step');
    expect(c.fieldErrors[ScheduleFormController.fieldBreak]?.key, AdminTextKeys.scheduleErrorBreakIncomplete);

    c
      ..setBreakLength(30)
      ..next();
    expect(c.step, ScheduleStep.attendance);
    c.next();
    expect((c.step, c.onLastStep, c.canSave), (ScheduleStep.review, true, true));

    c.back();
    expect(c.step, ScheduleStep.attendance);
  });

  test('saves the whole schedule in one request: hours, break on every working day, tolerance, rounding', () async {
    final c = await filledIn();
    c
      ..setBreakLength(30)
      ..next()
      ..arrivalTolerance = '5'
      ..leavingTolerance = '0'
      ..setStartRounding(const ScheduleRounding(intervalMinutes: 15, roundUp: true))
      ..next();

    expect(await c.submit(), isNotNull);

    final (method, groupId, request as SetGroupScheduleRequest) = api.writes.single;
    expect((method, groupId), ('setSchedule', 2));
    expect([for (final d in request.workHours.days) (d.dayId, d.start, d.finish)], [(11, '07:30', '16:00'), (15, '07:30', '16:00')]);
    expect(request.breakMinutes, 30, reason: 'the server places it in the middle of each day');
    expect((request.workHours.arrivalToleranceMinutes, request.workHours.leavingToleranceMinutes), (5, 0));
    expect(request.workHours.startRounding?.roundUp, isTrue);
    expect(request.workHours.finishRounding, isNull);
  });

  test('per-day hours are sent per day', () async {
    final c = await ready();
    c
      ..selectGroup(2)
      ..next()
      ..toggleDay(11)
      ..toggleDay(15)
      ..setSameHours(false)
      ..setDayStart(11, '08:00')
      ..setDayFinish(11, '16:30')
      ..setDayStart(15, '08:00')
      ..setDayFinish(15, '12:00')
      ..next()
      ..setBreakLength(15)
      ..next()
      ..next();

    await c.submit();

    final request = api.writes.single.$3 as SetGroupScheduleRequest;
    expect([for (final d in request.workHours.days) (d.dayId, d.finish)], [(11, '16:30'), (15, '12:00')]);
  });

  test('each step checks its own fields before moving on', () async {
    final c = await ready();
    c
      ..selectGroup(2)
      ..next()
      ..toggleDay(11)
      ..setStart('16:00')
      ..setFinish('08:00')
      ..next();
    expect(c.step, ScheduleStep.hours);
    expect(c.fieldErrors[ScheduleFormController.fieldHours]?.key, AdminTextKeys.scheduleErrorFinishBeforeStart);

    c
      ..setStart('08:00')
      ..setFinish('08:30')
      ..next()
      ..next();
    expect(c.fieldErrors[ScheduleFormController.fieldBreak]?.key, AdminTextKeys.scheduleErrorBreakIncomplete);

    c
      ..setBreakLength(30)
      ..next();
    expect(c.fieldErrors[ScheduleFormController.fieldBreak]?.key, AdminTextKeys.scheduleErrorBreakOutside,
        reason: 'a 30-minute break in a 30-minute day');

    c
      ..setBreakLength(15)
      ..next()
      ..arrivalTolerance = '61'
      ..next();
    expect(c.step, ScheduleStep.attendance);
    expect(c.fieldErrors[ScheduleFormController.fieldArrival]?.key, AdminTextKeys.scheduleErrorTolerance);
    expect(api.writes, isEmpty);
  });

  test('a group with no employee only in it is blocked; one with a schedule is a conflict until editing', () async {
    final c = await ready();

    c.selectGroup(3);
    expect((c.blocked, c.canContinue), (true, false));

    c.selectGroup(1);
    expect((c.conflict, c.canContinue), (true, false));

    c.editExisting();
    expect((c.editing, c.conflict, c.canContinue), (true, false, true));
  });

  test('editing fills in the hours, the break and the attendance rules', () async {
    final c = await ready(group: blue);

    expect(c.dayIds, {11, 12, 13, 14, 15});
    expect((c.sameHours, c.start, c.finish, c.arrivalTolerance), (true, '08:00', '16:30', '10'));
    expect(c.breakLength, 30);
    expect(c.startRounding?.roundUp, isTrue);
    expect(c.finishRounding?.roundUp, isFalse);
  });

  test('server refusals return to the step concerned', () async {
    final c = await ready(group: blue);
    c
      ..next()
      ..next()
      ..next()
      ..next();
    expect(c.step, ScheduleStep.review);

    api.writeFailure = ApiClientExceptionFor.validation(SetGroupScheduleRequest.fieldBreakMinutes);
    expect(await c.submit(), isNull);
    expect(c.step, ScheduleStep.hours, reason: 'the break is on the hours step');

    api.writeFailure = ApiClientExceptionFor.validation(SetWorkHoursRequest.fieldDays);
    await c.submit();
    expect(c.step, ScheduleStep.hours);

    api.writeFailure = serverError(409, ApiErrorCode.groupWithoutEmployees);
    await c.submit();
    expect(c.step, ScheduleStep.group);
    expect(c.fieldErrors[ScheduleFormController.fieldForm]?.key, AdminTextKeys.scheduleFormBlocked);

    api.writeFailure = serverError(503, ApiErrorCode.databaseUnavailable);
    await c.submit();
    expect(c.failure?.error?.code, ApiErrorCode.databaseUnavailable);
    expect(c.submitting, isFalse);
  });

  test('"Mon–Fri" selects exactly the given days', () async {
    final c = await ready();
    c
      ..toggleDay(17)
      ..selectDays([11, 12, 13, 14, 15]);
    expect(c.dayIds, {11, 12, 13, 14, 15});
  });

  test('typed times are tidied to HH:mm; anything else is not a time', () {
    for (final (typed, tidy) in [('0730', '07:30'), ('730', '07:30'), ('7:30', '07:30'), ('7.30', '07:30'), ('16:00', '16:00')]) {
      expect(tidyTime(typed), tidy, reason: typed);
    }
    for (final typed in ['', '7', '24:00', '12:60', '1:2', '12345', '12::30']) {
      expect(tidyTime(typed), isNull, reason: typed);
    }
  });

  test('a time typed wrongly stops at its step', () async {
    final c = await ready();
    c
      ..selectGroup(2)
      ..next()
      ..toggleDay(11)
      ..setStart('8')
      ..setFinish('16:00')
      ..next();

    expect(c.step, ScheduleStep.hours);
    expect(c.fieldErrors[ScheduleFormController.fieldHours]?.key, AdminTextKeys.scheduleErrorDays);
  });
}

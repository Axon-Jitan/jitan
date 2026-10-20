import 'package:admin_web/src/l10n/admin_text_keys.dart';
import 'package:admin_web/src/schedules/schedule_form_controller.dart';
import 'package:admin_web/src/schedules/schedule_rows.dart';
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

  Future<ScheduleFormController> ready({GroupSchedule? group, ScheduleKind? kind}) async {
    final c = ScheduleFormController(api, groups: groups, group: group, kind: kind);
    final loading = c.loadOptions();
    api.succeedOptions();
    await loading;
    return c;
  }

  setUp(() => api = FakeSchedulesApi());

  test('create work hours: sends the selected days, times, tolerance and rounding', () async {
    final c = await ready();
    c
      ..selectGroup(2)
      ..toggleDay(11)
      ..toggleDay(15)
      ..setStart('07:30')
      ..setFinish('16:00')
      ..arrivalTolerance = '5'
      ..leavingTolerance = '0'
      ..setStartRounding(const ScheduleRounding(intervalMinutes: 15, roundUp: true));

    expect(await c.submit(), isNotNull);

    final (method, groupId, request as SetWorkHoursRequest) = api.writes.single;
    expect((method, groupId), ('setWorkHours', 2));
    expect([for (final d in request.days) (d.dayId, d.start, d.finish)], [(11, '07:30', '16:00'), (15, '07:30', '16:00')]);
    expect((request.arrivalToleranceMinutes, request.leavingToleranceMinutes), (5, 0));
    expect(request.startRounding?.roundUp, isTrue);
    expect(request.finishRounding, isNull);
  });

  test('per-day hours are sent per day', () async {
    final c = await ready();
    c
      ..selectGroup(2)
      ..toggleDay(11)
      ..toggleDay(15)
      ..setSameHours(false)
      ..setDayStart(11, '08:00')
      ..setDayFinish(11, '16:30')
      ..setDayStart(15, '08:00')
      ..setDayFinish(15, '12:00');

    await c.submit();

    final request = api.writes.single.$3 as SetWorkHoursRequest;
    expect([for (final d in request.days) (d.dayId, d.finish)], [(11, '16:30'), (15, '12:00')]);
  });

  test('Save waits for a group and a day; then tolerance out of range and finish before start are caught', () async {
    final c = await ready();
    expect((c.missingRequired, c.canSave), (true, false));
    c.selectGroup(2);
    expect((c.missingRequired, c.canSave), (true, false), reason: 'no day yet');
    expect(await c.submit(), isNull);

    c
      ..toggleDay(11)
      ..setStart('08:00')
      ..setFinish('16:00')
      ..arrivalTolerance = '61'
      ..leavingTolerance = 'x';
    expect(c.canSave, isTrue);
    expect(await c.submit(), isNull);
    expect(c.fieldErrors[ScheduleFormController.fieldArrival]?.key, AdminTextKeys.scheduleErrorTolerance);
    expect(c.fieldErrors[ScheduleFormController.fieldLeaving]?.key, AdminTextKeys.scheduleErrorTolerance);

    c
      ..setStart('16:00')
      ..setFinish('08:00')
      ..arrivalTolerance = '0'
      ..leavingTolerance = '0';
    expect(await c.submit(), isNull);
    expect(c.fieldErrors[ScheduleFormController.fieldHours]?.key, AdminTextKeys.scheduleErrorFinishBeforeStart);
    expect(api.writes, isEmpty);
  });

  test('a group with no employee only in it is blocked; one with that kind already is a conflict', () async {
    final c = await ready();

    c.selectGroup(3);
    expect((c.blocked, c.canSave), (true, false));

    c.selectGroup(1);
    expect((c.conflict, c.canSave), (true, false));

    c.editExisting();
    expect((c.editing, c.conflict, c.canSave), (true, false, true));
    expect(c.dayIds, {11, 12, 13, 14, 15});
    expect((c.sameHours, c.start, c.finish, c.arrivalTolerance), (true, '08:00', '16:30', '10'));
    expect(c.startRounding?.roundUp, isTrue);
    expect(c.finishRounding?.roundUp, isFalse);
  });

  test('editing breaks is filled in from the group', () async {
    final c = await ready(group: blue, kind: ScheduleKind.breaks);

    expect((c.editing, c.breakStart, c.breakLength, c.dayIds.length), (true, '12:00', 30, 5));
  });

  test('a break outside the work hours, or for a group without work hours, is refused before sending', () async {
    final c = await ready(group: blue, kind: ScheduleKind.breaks);
    c.setBreakStart('16:15');
    expect(await c.submit(), isNull);
    expect(c.fieldErrors[ScheduleFormController.fieldBreak]?.key, AdminTextKeys.scheduleErrorBreakOutside);

    final other = await ready();
    other
      ..selectGroup(2)
      ..selectKind(ScheduleKind.breaks)
      ..toggleDay(11)
      ..setBreakStart('12:00')
      ..setBreakLength(30);
    expect(await other.submit(), isNull);
    expect(other.fieldErrors[ScheduleFormController.fieldBreak]?.key, AdminTextKeys.scheduleErrorBreaksNeedHours);
    expect(api.writes, isEmpty);
  });

  test('server refusals: validation goes to its field, 409s to the form, anything else is a failure', () async {
    final c = await ready(group: blue, kind: ScheduleKind.workHours);

    api.writeFailure = serverError(400, ApiErrorCode.validationFailed);
    expect(await c.submit(), isNull);
    expect(c.fieldErrors[ScheduleFormController.fieldHours]?.key, AdminTextKeys.scheduleErrorDays);

    api.writeFailure = serverError(409, ApiErrorCode.groupWithoutEmployees);
    await c.submit();
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

  test('wizard: Continue needs a group (step 1) and a day (step 2); each step checks its own fields', () async {
    final c = await ready();
    expect((c.step, c.canContinue), (0, false));
    c.next();
    expect(c.step, 0, reason: 'no group yet');

    c.selectGroup(2);
    c.next();
    expect((c.step, c.canContinue), (1, false), reason: 'no day yet');

    c
      ..toggleDay(11)
      ..setStart('16:00')
      ..setFinish('08:00');
    c.next();
    expect(c.step, 1);
    expect(c.fieldErrors[ScheduleFormController.fieldHours]?.key, AdminTextKeys.scheduleErrorFinishBeforeStart);

    c.setFinish('17:00');
    c.next();
    expect((c.step, c.onLastStep), (2, true));

    c.back();
    expect(c.step, 1);
    expect(c.start, '16:00', reason: 'going back keeps the answers');
  });

  test('a server refusal of the hours goes back to step 2', () async {
    final c = await ready(group: blue, kind: ScheduleKind.workHours);
    c
      ..next()
      ..next();
    expect(c.step, 2);

    api.writeFailure = serverError(400, ApiErrorCode.validationFailed);
    await c.submit();
    expect(c.step, 1);
  });

  test('time choices are every 5 minutes of the day', () {
    expect(ScheduleFormController.timeChoices.length, 288);
    expect(ScheduleFormController.timeChoices.first, '00:00');
    expect(ScheduleFormController.timeChoices.last, '23:55');
  });
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  (SchedulesApi, List<Uri>) api(Object body) {
    final urls = <Uri>[];
    return (
      SchedulesApi(ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient((request) async {
          urls.add(request.url);
          return http.Response(jsonEncode(body), 200);
        }),
      )),
      urls,
    );
  }

  const monday = ScheduleDay(id: 1, name: 'Monday', weekday: 1);

  test('reads the groups\' schedules', () async {
    final (client, urls) = api(const GroupScheduleListResponse(groups: [
      GroupSchedule(
        group: GroupSummary(id: 2, name: 'Blue collar'),
        status: GroupScheduleStatus.configured,
        singleGroupEmployeeCount: 3,
        variants: [
          ScheduleVariant(
            employeeCount: 3,
            favour: ScheduleRoundingFavour.company,
            workDays: [
              WorkDaySchedule(
                day: monday,
                start: WorkBoundary(time: '08:00', toleranceMinutes: 10, rounding: ScheduleRounding(intervalMinutes: 15, roundUp: true)),
                finish: WorkBoundary(time: '16:30', toleranceMinutes: 10),
              ),
            ],
            breaks: [BreakSchedule(day: monday, usualStart: '12:00', lengthMinutes: 30)],
          ),
        ],
      ),
    ]).toJson());

    final groups = await client.groupSchedules();

    expect(urls.single.path, '/schedules');
    final variant = groups.single.variants.single;
    expect(variant.workDays.single.start!.rounding!.roundUp, isTrue);
    expect(variant.workDays.single.finish!.rounding, isNull);
    expect(variant.breaks.single.lengthMinutes, 30);
  });

  test('reads the form options', () async {
    final (client, urls) = api(const ScheduleOptions(
      days: [monday],
      roundingIntervalMinutes: [15, 30, 60],
      toleranceMinutes: [0, 5, 10, 15],
      breakLengthMinutes: [15, 30, 45, 60],
    ).toJson());

    final options = await client.options();

    expect(urls.single.path, '/schedules/options');
    expect(options.days.single.weekday, 1);
    expect(options.toleranceMinutes, [0, 5, 10, 15]);
  });

  test('saves and removes work hours and breaks of a group', () async {
    const group = GroupSchedule(
      group: GroupSummary(id: 2, name: 'Blue collar'),
      status: GroupScheduleStatus.noSchedule,
      singleGroupEmployeeCount: 3,
      variants: [],
    );
    final requests = <http.Request>[];
    final client = SchedulesApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(group.toJson()), 200);
      }),
    ));

    await client.setWorkHours(
      2,
      const SetWorkHoursRequest(
        days: [WorkHoursDay(dayId: 1, start: '08:00', finish: '16:30')],
        startToleranceMinutes: 10,
        finishToleranceMinutes: 10,
        startIntervalMinutes: 15,
        finishIntervalMinutes: 15,
        favour: ScheduleRoundingFavour.company,
      ),
    );
    await client.removeWorkHours(2);
    await client.setBreaks(2, const SetBreaksRequest(days: [BreakDay(dayId: 1, usualStart: '12:00', lengthMinutes: 30)]));
    final removed = await client.removeBreaks(2);

    expect([for (final r in requests) '${r.method} ${r.url.path}'], [
      'PUT /schedules/groups/2/work-hours',
      'DELETE /schedules/groups/2/work-hours',
      'PUT /schedules/groups/2/breaks',
      'DELETE /schedules/groups/2/breaks',
    ]);
    expect((jsonDecode(requests.first.body) as Map)['favour'], 'company');
    expect(removed.status, GroupScheduleStatus.noSchedule);
  });

  test('a malformed body is an invalid response, not a crash', () async {
    final (client, _) = api({'groups': 'nope'});

    expect(client.groupSchedules(), throwsA(isA<ApiClientException>()));
  });
}

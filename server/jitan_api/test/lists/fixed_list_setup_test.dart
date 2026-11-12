import 'dart:async';

import 'package:jitan_api/src/auth/request_identity.dart';
import 'package:jitan_api/src/lists/fixed_list_setup.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Jitan completes its own fixed lists (product owner, 2026-11-12).
void main() {
  late List<int> runs;
  late bool complete;
  late Object? failure;
  late Set<int> managers;
  late DateTime now;
  late Completer<void>? hold;

  FixedListSetup setup() => FixedListSetup(
    addAllMissing: (actor) async {
      runs.add(actor);
      await hold?.future;
      if (failure case final error?) throw error;
      return complete;
    },
    mayManage: (request) async => managers.contains(request.identity.userId),
    clock: () => now,
  );

  Request request([int? userId]) {
    final plain = Request('GET', Uri.parse('http://localhost/dashboard'));
    return userId == null ? plain : plain.withIdentity(RequestIdentity(userId: userId));
  }

  Future<Response> send(FixedListSetup setup, Request request) =>
      Future.sync(() => setup.middleware((_) => Response.ok('on'))(request));

  setUp(() {
    runs = [];
    complete = true;
    failure = null;
    managers = {1};
    now = DateTime(2026, 11, 12, 9);
    hold = null;
  });

  test('the first request of someone who may manage the lists completes them, once', () async {
    final lists = setup();

    expect((await send(lists, request(1))).statusCode, 200);
    await send(lists, request(1));

    expect(runs, [1], reason: 'once per start, under that person');
  });

  test('nobody else completes them, and a request without a user goes on untouched', () async {
    final lists = setup();

    expect((await send(lists, request(2))).statusCode, 200);
    expect((await send(lists, request())).statusCode, 200);

    expect(runs, isEmpty);
  });

  test('after a failure the request goes on, and Jitan tries again only later', () async {
    final lists = setup();
    failure = StateError('no INSERT right');

    expect((await send(lists, request(1))).statusCode, 200, reason: 'the request never fails for it');
    await send(lists, request(1));
    expect(runs, [1], reason: 'not again right away');

    failure = null;
    now = now.add(const Duration(minutes: 11));
    await send(lists, request(1));
    expect(runs, [1, 1]);
  });

  test('still incomplete counts as not done: tried again later', () async {
    final lists = setup();
    complete = false;

    await send(lists, request(1));
    now = now.add(const Duration(minutes: 11));
    complete = true;
    await send(lists, request(1));
    await send(lists, request(1));

    expect(runs, [1, 1]);
  });

  test('requests at the same moment share one run', () async {
    final lists = setup();
    hold = Completer<void>();

    final first = send(lists, request(1));
    final second = send(lists, request(1));
    await Future<void>.delayed(Duration.zero);
    hold!.complete();
    await Future.wait([first, second]);

    expect(runs, [1]);
  });
}

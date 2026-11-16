import 'dart:async';

import 'package:jitan_api/src/database/connection_pool.dart';
import 'package:test/test.dart';

class _Connection {
  _Connection(this.id);

  final int id;
  bool open = true;
  bool closed = false;
}

void main() {
  late List<_Connection> opened;
  late ConnectionPool<_Connection> pool;

  ConnectionPool<_Connection> poolOf(int max) => ConnectionPool<_Connection>(
        open: () async => _Connection(opened.length)..also(opened.add),
        isOpen: (c) => c.open,
        close: (c) async {
          c
            ..open = false
            ..closed = true;
        },
        maxConnections: max,
      );

  setUp(() {
    opened = [];
    pool = poolOf(2);
  });

  test('a connection is used again after its work, also when the work failed', () async {
    await pool.withConnection((c) async {});
    await expectLater(pool.withConnection<void>((c) async => throw StateError('query failed')), throwsStateError);
    await pool.withConnection((c) async {});

    expect(opened, hasLength(1));
    expect(pool.idle, 1);
  });

  test('a discarded connection is closed, never handed out again (review L8)', () async {
    await pool.withConnection((c) async => pool.discard(c));

    expect(opened.single.closed, isTrue);
    expect(pool.size, 0);
    await pool.withConnection((c) async => expect(c, isNot(same(opened.first))));
    expect(opened, hasLength(2));
  });

  test('a connection that closed by itself is not handed out again', () async {
    await pool.withConnection((c) async {});
    opened.single.open = false;

    await pool.withConnection((c) async => expect(c.id, 1));
    expect(pool.size, 1);
  });

  test('at most maxConnections at once; the next one waits for a free connection', () async {
    final release = Completer<void>();
    final busy = [for (var i = 0; i < 2; i++) pool.withConnection((c) => release.future)];
    var third = false;
    final waiting = pool.withConnection((c) async => third = true);
    await Future<void>.delayed(Duration.zero);

    expect(opened, hasLength(2));
    expect(third, isFalse);
    release.complete();
    await Future.wait([...busy, waiting]);
    expect(third, isTrue);
    expect(opened, hasLength(2));
  });

  test('someone waiting gets a new connection when the freed one was discarded', () async {
    final release = Completer<void>();
    final first = pool.withConnection((c) async {
      await release.future;
      pool.discard(c);
    });
    final second = pool.withConnection((c) => release.future);
    final waiting = pool.withConnection((c) async => c.id);
    await Future<void>.delayed(Duration.zero);

    release.complete();
    await Future.wait([first, second]);
    expect(await waiting, isIn([1, 2]));
    expect(pool.size, lessThanOrEqualTo(2));
  });

  test('a failed open frees its place', () async {
    var fail = true;
    final flaky = ConnectionPool<_Connection>(
      open: () async {
        if (fail) throw StateError('unreachable');
        return _Connection(0);
      },
      isOpen: (c) => c.open,
      close: (c) async => c.open = false,
      maxConnections: 1,
    );

    await expectLater(flaky.withConnection((c) async {}), throwsStateError);
    fail = false;
    await flaky.withConnection((c) async {});
    expect(flaky.size, 1);
  });
}

extension<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}

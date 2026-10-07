// Measures Argon2id cost on the machine that will run the API, to choose
// JITAN_ARGON2_MEMORY_KIB / _ITERATIONS / _PARALLELISM for production.
//
//   dart run tool/bench_argon2.dart            # candidate grid
//   dart run tool/bench_argon2.dart 19456 2 1  # one configuration
//
// `dart run` is JIT and about 2x slower; for numbers that match a compiled
// server, `dart compile exe tool/bench_argon2.dart -o bench` and run `bench`.
//
// Aim for roughly 150-500 ms per hash with the memory the server can spare
// under expected concurrent sign-ins (each hash holds memoryKiB while it runs).
// Uses a throwaway password; nothing is written or logged elsewhere.
import 'dart:io';

import 'package:jitan_api/src/auth/password_hasher.dart';

const _rounds = 5;

Future<void> main(List<String> args) async {
  final candidates = args.isEmpty
      ? const [
          Argon2idParameters(memoryKiB: 19456, iterations: 2),
          Argon2idParameters(memoryKiB: 47104, iterations: 1),
          Argon2idParameters(memoryKiB: 65536, iterations: 2),
          Argon2idParameters(memoryKiB: 65536, iterations: 3),
        ]
      : [
          Argon2idParameters(
            memoryKiB: int.parse(args[0]),
            iterations: args.length > 1 ? int.parse(args[1]) : 2,
            parallelism: args.length > 2 ? int.parse(args[2]) : 1,
          ),
        ];

  stdout.writeln(
    '${Platform.operatingSystemVersion}, ${Platform.numberOfProcessors} CPUs, Dart ${Platform.version.split(' ').first}',
  );
  for (final parameters in candidates) {
    if (!parameters.isWithinBounds) {
      stderr.writeln('$parameters is outside the accepted bounds; skipped.');
      continue;
    }
    final hasher = PasswordHasher(parameters: parameters);
    await hasher.hash('warm-up password'); // first isolate spawn, JIT
    final times = <int>[];
    for (var i = 0; i < _rounds; i++) {
      final watch = Stopwatch()..start();
      final hash = await hasher.hash('benchmark password $i');
      if (!await hasher.verify('benchmark password $i', hash)) throw StateError('verify failed');
      times.add(watch.elapsedMilliseconds ~/ 2); // hash + verify
    }
    times.sort();
    stdout.writeln('$parameters: median ${times[_rounds ~/ 2]} ms per hash (min ${times.first}, max ${times.last})');
  }
}

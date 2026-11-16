import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';

/// At most [limit] password hashes at a time in this process (review M2,
/// 2026-11-16). Each Argon2id run takes about 19 MiB and a full core, so a
/// flood of sign-ins could otherwise take all memory and CPU. Others wait
/// their turn, up to [maxWait]; after that they get 503 "busy".
class HashingSlots {
  HashingSlots({int? limit, this.maxWait = const Duration(seconds: 10)})
    : limit = limit ?? Platform.numberOfProcessors.clamp(1, 8);

  /// The process's slots, shared by every [PasswordHasher].
  static final shared = HashingSlots();

  final int limit;
  final Duration maxWait;
  int _running = 0;
  final _waiting = Queue<Completer<void>>();

  int get running => _running;

  /// Runs [work] once a slot is free.
  Future<T> run<T>(Future<T> Function() work) async {
    if (_running >= limit) {
      final turn = Completer<void>();
      _waiting.add(turn);
      try {
        await turn.future.timeout(maxWait);
      } on TimeoutException {
        _waiting.remove(turn);
        throw const ApiException(503, ApiErrorCode.databaseUnavailable, 'Jitan is busy. Please try again in a moment.');
      }
    } else {
      _running++;
    }
    try {
      return await work();
    } finally {
      // The slot passes straight to the next one waiting, or is freed.
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _running--;
      }
    }
  }
}

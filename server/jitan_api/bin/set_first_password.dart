import 'dart:convert';
import 'dart:io';

import 'package:jitan_api/src/auth/first_password_service.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/auth/password_policy.dart';
import 'package:jitan_api/src/config/app_config.dart';
import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/config_sources.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';

/// IT gives the very first HR person a password on a fresh database (AUTH-03):
///
/// ```sh
/// set_first_password SBW
/// ```
///
/// Uses the server's own configuration. The password is asked for, never
/// taken from the command line, so it stays out of the shell history. It is
/// refused for an account that already has a password.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: set_first_password <employee code>');
    exitCode = 64; // EX_USAGE
    return;
  }

  final Database db;
  final Argon2idParameters hashing;
  try {
    final config = AppConfig.fromSources(ConfigSources.load(Platform.environment));
    hashing = config.passwordHashing;
    db = Database.connect(config.database);
  } on ConfigException catch (e) {
    stderr.writeln('The configuration is not usable: ${e.message}');
    exitCode = 78; // EX_CONFIG
    return;
  }

  final input = stdin.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
  Future<String> ask(String question) async {
    stdout.write(question);
    if (stdin.hasTerminal) stdin.echoMode = false;
    final answer = await input.first;
    if (stdin.hasTerminal) {
      stdin.echoMode = true;
      stdout.writeln();
    }
    return answer;
  }

  try {
    final password = await ask('New password (at least ${PasswordPolicy.minLength} characters): ');
    if (await ask('Again: ') != password) {
      stderr.writeln('The two passwords are not the same. Nothing was changed.');
      exitCode = 1;
      return;
    }
    final result = await FirstPasswordService(transactions: db, hasher: PasswordHasher(parameters: hashing)).set(arguments.single, password);
    switch (result) {
      case FirstPasswordResult.set:
        stdout.writeln('Done. ${arguments.single} can now sign in.');
      case FirstPasswordResult.noSuchEmployee:
        stderr.writeln('No active employee has that code. Nothing was changed.');
        exitCode = 1;
      case FirstPasswordResult.ambiguousCode:
        stderr.writeln('Several employees have that code. Nothing was changed.');
        exitCode = 1;
      case FirstPasswordResult.alreadyHasPassword:
        stderr.writeln('That account already has a password. Nothing was changed.');
        exitCode = 1;
    }
  } on ApiException catch (e) {
    stderr.writeln('${e.message} Nothing was changed.');
    exitCode = 1;
  } finally {
    await db.close();
  }
}

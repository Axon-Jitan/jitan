import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jitan_api/src/auth/first_hr_repository.dart';
import 'package:jitan_api/src/auth/first_hr_setup_service.dart';
import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:jitan_api/src/auth/password_policy.dart';
import 'package:jitan_api/src/config/app_config.dart';
import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/config_sources.dart';
import 'package:jitan_api/src/database/database.dart';
import 'package:jitan_api/src/http/api_exception.dart';

/// Sets up the very first HR person in one step (IT_INSTALL_GUIDE, step 4):
///
/// ```sh
/// ./jitan-first-hr
/// ```
///
/// IT runs it on the server, with the server's own configuration, and the
/// person beside it. It asks for the employee code (and the name when the code
/// is new), the access group, the module when that group opens none yet, and
/// the password, which the person types: it is never shown, never taken from
/// the command line and never printed. Everything happens together or not at
/// all, and is audited.
Future<void> main(List<String> arguments) async {
  final Database db;
  final FirstHrSetupService service;
  try {
    final config = AppConfig.fromSources(ConfigSources.load(Platform.environment));
    db = Database.connect(config.database);
    service = FirstHrSetupService(
      transactions: db,
      executor: db,
      hasher: PasswordHasher(parameters: config.passwordHashing),
    );
  } on ConfigException catch (e) {
    stderr.writeln('The configuration is not usable: ${e.message}');
    exitCode = 78; // EX_CONFIG
    return;
  }

  // Holds the lines until each question asks for one, also when the answers
  // are pasted in at once.
  final input = StreamIterator(stdin.transform(utf8.decoder).transform(const LineSplitter()));
  Future<String> ask(String question, {bool hidden = false}) async {
    stdout.write(question);
    final hide = hidden && stdin.hasTerminal;
    if (hide) stdin.echoMode = false;
    final answer = await input.moveNext() ? input.current : '';
    if (hide) {
      stdin.echoMode = true;
      stdout.writeln();
    }
    // A password is taken exactly as typed (PasswordPolicy never trims).
    return hidden ? answer : answer.trim();
  }

  Future<int?> choose(String title, List<AccessOption> options) async {
    stdout.writeln(title);
    for (final (i, option) in options.indexed) {
      stdout.writeln('  ${i + 1}) ${option.name}');
    }
    final picked = int.tryParse(await ask('Choose 1-${options.length}: '));
    if (picked == null || picked < 1 || picked > options.length) return null;
    return options[picked - 1].id;
  }

  void stop(String message) {
    stderr.writeln('$message Nothing was changed.');
    exitCode = 1;
  }

  try {
    stdout.writeln('Jitan: set up the first HR person.');
    final code = await ask('Employee code: ');
    if (code.isEmpty) return stop('No employee code.');

    final found = await service.lookUp(code);
    String? firstName;
    String? lastName;
    switch (found.code) {
      case FirstHrCode.ambiguous:
        return stop('Several employees have that code.');
      case FirstHrCode.hasPassword:
        return stop('${found.name} already has a password: they can sign in.');
      case FirstHrCode.taken:
        return stop('That code belongs to a switched-off or removed employee.');
      case FirstHrCode.existing:
        stdout.writeln('Found: ${found.name}.');
      case FirstHrCode.newEmployee:
        stdout.writeln('New employee.');
        firstName = await ask('First name: ');
        lastName = await ask('Last name: ');
    }

    final groups = await service.accessGroups();
    if (groups.isEmpty) return stop('tblCredGroup has no active access group yet: add one (for example HR) first.');
    final groupId = await choose('Access group:', groups);
    if (groupId == null) return stop('No access group chosen.');

    int? moduleId;
    if (!await service.opensAModule(groupId)) {
      final modules = await service.modules();
      if (modules.isEmpty) return stop('tblAppModules has no active module yet: add one (for example HR) first.');
      moduleId = await choose('This group opens no part of Jitan yet. Which one may it open?', modules);
      if (moduleId == null) return stop('No module chosen.');
    }

    stdout.writeln('Now the HR person types their password (it is not shown).');
    final password = await ask('Password (at least ${PasswordPolicy.minLength} characters): ', hidden: true);
    if (await ask('Again: ', hidden: true) != password) return stop('The two passwords are not the same.');

    final result = await service.setUp(code: code, firstName: firstName, lastName: lastName, credGroupId: groupId, moduleId: moduleId, password: password);
    switch (result) {
      case FirstHrResult.done:
        stdout.writeln('Done. $code can now sign in on the HR website.');
      case FirstHrResult.ambiguousCode:
        stop('Several employees have that code.');
      case FirstHrResult.alreadyHasPassword:
        stop('That account already has a password.');
      case FirstHrResult.codeTaken:
        stop('That code belongs to a switched-off or removed employee.');
      case FirstHrResult.unknownGroup:
        stop('That access group is no longer active.');
      case FirstHrResult.moduleNeeded:
        stop('That module is no longer active.');
    }
  } on ApiException catch (e) {
    stop(e.message);
  } finally {
    await input.cancel();
    await db.close();
  }
}

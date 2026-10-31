import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../time_records/my_day_service.dart';
import '../time_registration/time_registration_write_repository.dart';
import '../time_registration/workplace_clock.dart';
import 'activity_repository.dart';

/// The day as a sequence of activities (D19, D22, D37). Switching changes
/// only what the time counts for: it adds a row of its own, and the day's
/// Start and Finish rows stay as they are.
///
/// The default project (D16, D38) needs no setting: someone with one project
/// has that one, someone with several the one used last, and otherwise work
/// simply starts without a project. A company switch lasts for the day.
class ActivityService {
  ActivityService({
    required this._activities,
    required this._writes,
    required this._myDay,
    required this._audit,
    required this._transactions,
    required this._executor,
    required this._clock,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ActivityRepository _activities;
  final TimeRegistrationWriteRepository _writes;
  final MyDayService _myDay;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;
  final WorkplaceClock _clock;
  final DateTime Function() _now;

  /// How far ahead of the server's clock a time may be.
  static const _allowedClockSkew = Duration(minutes: 2);

  static const _typeNames = {
    ActivityKind.work: 'Activity – Work',
    ActivityKind.clientOnSite: 'Activity – Client on site',
    ActivityKind.clientInHouse: 'Activity – Client in-house',
    ActivityKind.internal: 'Activity – Internal',
    ActivityKind.transport: 'Activity – Transport',
  };

  Future<MyActivity> mine(int userId) async {
    final projects = await _activities.projects(_executor, userId);
    final companies = await _activities.companies(_executor, userId);
    final current = await _current(userId, projects, companies);
    return MyActivity(
      enabled: true,
      current: current,
      projects: [for (final p in projects) p.project],
      companies: companies,
    );
  }

  /// 409 while the day isn't running; 400 for a project that isn't theirs or
  /// an activity that doesn't fit it. The same switch again (a retry) changes
  /// nothing.
  Future<MyActivity> switchTo(int userId, SwitchActivityRequest request) async {
    final at = DateTime.fromMillisecondsSinceEpoch(request.at.millisecondsSinceEpoch ~/ 1000 * 1000, isUtc: true);
    if (at.isAfter(_now().toUtc().add(_allowedClockSkew))) {
      throw const ApiException.validation(SwitchActivityRequest.fieldAt, 'A switch can’t be in the future.');
    }
    final today = await _myDay.today(userId);
    final day = today.day;
    if (day == null || day.finish != null || (day.start == null && day.pending.isEmpty)) {
      throw const ApiException(409, ApiErrorCode.workdayNotRunning, 'Start the day first.');
    }
    final projects = await _activities.projects(_executor, userId);
    final companies = await _activities.companies(_executor, userId);
    final project = request.projectId == null ? null : _assigned(projects, request.projectId!);
    _checkFits(request.kind, project);
    final companyId = project?.companyId ?? request.companyId;
    if (companyId != null && !companies.any((c) => c.id == companyId)) {
      throw const ApiException.validation(SwitchActivityRequest.fieldCompany, 'This is not one of your companies.');
    }

    await _transactions.transaction((tx) async {
      await _writes.lockUser(tx, userId);
      final typeId = await _typeOf(tx, request.kind);
      final (from, to) = _todayBounds();
      final latest = (await _activities.between(tx, userId, from, to)).lastOrNull;
      if (latest != null && latest.at == at && latest.projectId == project?.id && latest.typeName == _typeNames[request.kind]) {
        return;
      }
      final id = await _activities.insert(
        tx,
        userId: userId,
        typeId: typeId,
        at: at,
        projectId: project?.id,
        companyId: companyId,
      );
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.activitySwitched,
          actorUserId: userId,
          references: {
            EventLogReference.user: userId,
            EventLogReference.timeReg: id,
            EventLogReference.timeRegType: typeId,
            EventLogReference.project: ?project?.id,
            EventLogReference.company: ?companyId,
          },
        ),
      );
    });
    return mine(userId);
  }

  /// Stores what the day starts on, in the transaction of the start. Nothing
  /// to store without a project or a company.
  Future<void> dayStarted(SqlExecutor tx, int userId, DateTime at) async {
    final projects = await _activities.projects(tx, userId);
    final companies = await _activities.companies(tx, userId);
    final project = _defaultProject(projects);
    final company = _defaultCompany(companies);
    if (project == null && company == null) return;
    final kind = project == null
        ? ActivityKind.work
        : project.isClient
        ? ActivityKind.clientOnSite
        : ActivityKind.internal;
    await _activities.insert(
      tx,
      userId: userId,
      typeId: await _typeOf(tx, kind),
      at: at,
      projectId: project?.id,
      companyId: project?.companyId ?? company?.id,
    );
  }

  Future<CurrentActivity?> _current(
    int userId,
    List<AssignedProject> projects,
    List<MyCompany> companies,
  ) async {
    final (from, to) = _todayBounds();
    final latest = (await _activities.between(_executor, userId, from, to)).lastOrNull;
    if (latest == null) return null;
    MyProject? project;
    for (final p in projects) {
      if (p.project.id == latest.projectId) project = p.project;
    }
    return CurrentActivity(
      kind: _kindOf(latest.typeName),
      since: latest.at,
      project: project,
      company: companies.where((c) => c.id == latest.companyId).firstOrNull,
    );
  }

  /// One project: that one. Several: the one used last.
  static MyProject? _defaultProject(List<AssignedProject> projects) {
    final current = [
      for (final p in projects)
        if (p.project.isCurrent) p,
    ];
    if (current.length == 1) return current.single.project;
    final used = current.where((p) => p.lastUsed != null).toList()..sort((a, b) => b.lastUsed!.compareTo(a.lastUsed!));
    return used.firstOrNull?.project;
  }

  static MyCompany? _defaultCompany(List<MyCompany> companies) =>
      companies.where((c) => c.isDefault).firstOrNull ?? (companies.length == 1 ? companies.single : null);

  static MyProject _assigned(List<AssignedProject> projects, int projectId) {
    for (final p in projects) {
      if (p.project.id == projectId && p.project.isCurrent) return p.project;
    }
    throw const ApiException.validation(SwitchActivityRequest.fieldProject, 'This is not one of your projects.');
  }

  static void _checkFits(ActivityKind kind, MyProject? project) {
    final fits = switch (kind) {
      ActivityKind.work => project == null,
      ActivityKind.transport => true,
      ActivityKind.internal => project != null,
      ActivityKind.clientOnSite || ActivityKind.clientInHouse => project?.isClient ?? false,
    };
    if (!fits) throw const ApiException.validation(SwitchActivityRequest.fieldKind, 'This activity doesn’t fit the project.');
  }

  static ActivityKind _kindOf(String typeName) =>
      _typeNames.entries.firstWhere((e) => e.value == typeName, orElse: () => _typeNames.entries.first).key;

  Future<int> _typeOf(SqlExecutor tx, ActivityKind kind) async {
    final name = _typeNames[kind]!;
    return await _writes.typeId(tx, name) ?? (throw ApiException.configurationError('tblTimeRegType has no "$name" row.'));
  }

  /// The workplace's today, in UTC.
  (DateTime, DateTime) _todayBounds() {
    final local = _clock.wallClockOf(_now().toUtc());
    return (
      _clock.utcOf(DateTime(local.year, local.month, local.day)),
      _clock.utcOf(DateTime(local.year, local.month, local.day + 1)),
    );
  }
}

import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../locations/location_repository.dart';
import '../projects/project_repository.dart';
import '../projects/project_service.dart';
import '../time_records/my_day_service.dart';
import '../time_registration/time_registration_write_repository.dart';
import '../time_registration/workplace_clock.dart';
import 'activity_entries.dart';
import 'activity_minutes.dart';
import 'activity_repository.dart';
import 'trip_kilometres.dart';

/// The day as a sequence of activities (D19, D22, D37). Switching changes
/// only what the time counts for: it adds a row of its own, and the day's
/// Start and Finish rows stay as they are.
///
/// Projects (D43, D44) are `tblAddress` rows of the kind "Project location",
/// and an activity row's `addressID` is its project or place. Anyone may
/// choose any active project. The default project (D38) needs no setting: it
/// is the one used last, and otherwise work starts without a project. The day
/// counts for the employee's default company.
class ActivityService {
  ActivityService({
    required this._activities,
    required this._projects,
    required this._writes,
    required this._myDay,
    required this._locations,
    required this._kilometres,
    required this._audit,
    required this._transactions,
    required this._executor,
    required this._clock,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ActivityRepository _activities;
  final ProjectRepository _projects;
  final TimeRegistrationWriteRepository _writes;
  final MyDayService _myDay;
  final LocationRepository _locations;
  final TripKilometres _kilometres;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;
  final WorkplaceClock _clock;
  final DateTime Function() _now;

  /// How far ahead of the server's clock a time may be.
  static const _allowedClockSkew = Duration(minutes: 2);

  /// The `tblTimeRegType` names of activities, for the Lists page.
  static Iterable<String> get typeNames => _typeNames.values;

  static const _typeNames = {
    ActivityKind.work: 'Activity – Work',
    ActivityKind.clientOnSite: 'Activity – Client on site',
    ActivityKind.clientInHouse: 'Activity – Client in-house',
    ActivityKind.internal: 'Activity – Internal',
    ActivityKind.transport: 'Activity – Transport',
  };

  Future<MyActivity> mine(int userId) async {
    final projects = await _projectsOf(_executor, userId);
    final companies = await _activities.companies(_executor, userId);
    return MyActivity(
      enabled: await _typesReady(_executor),
      current: await _current(userId, projects, companies),
      breakdown: await _breakdown(userId),
      today: await _entries(userId),
      projects: projects,
      companies: companies,
    );
  }

  /// 409 while the day isn't running; 400 for a project that isn't active or
  /// an activity that doesn't fit it. The same switch again (a retry) changes
  /// nothing.
  Future<MyActivity> switchTo(int userId, SwitchActivityRequest request) async {
    final at = _toSecond(request.at);
    if (at.isAfter(_now().toUtc().add(_allowedClockSkew))) {
      throw const ApiException.validation(SwitchActivityRequest.fieldAt, 'A switch can’t be in the future.');
    }
    final today = await _myDay.today(userId);
    final day = today.day;
    if (day == null || day.finish != null || (day.start == null && day.pending.isEmpty)) {
      throw const ApiException(409, ApiErrorCode.workdayNotRunning, 'Start the day first.');
    }
    final projects = await _projectsOf(_executor, userId);
    final project = request.projectId == null ? null : _active(projects, request.projectId!);
    _checkFits(request.kind, project);

    await _transactions.transaction((tx) async {
      await _writes.lockUser(tx, userId);
      final typeId = await _typeOf(tx, request.kind);
      final (from, to) = _todayBounds();
      final latest = (await _activities.between(tx, userId, from, to)).lastOrNull;
      if (latest != null && latest.at == at && latest.addressId == project?.id && latest.typeName == _typeNames[request.kind]) {
        return;
      }
      final id = await _activities.insert(tx, userId: userId, typeId: typeId, at: at, addressId: project?.id);
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.activitySwitched,
          actorUserId: userId,
          references: {
            EventLogReference.user: userId,
            EventLogReference.timeReg: id,
            EventLogReference.timeRegType: typeId,
            EventLogReference.address: ?project?.id,
          },
        ),
      );
    });
    return mine(userId);
  }

  /// On Automatic: left one location and stayed at another (D40). It is a
  /// trip when one end is a client project of theirs; moving between other
  /// workplaces simply continues the day. What they registered themselves
  /// meanwhile wins, and a retry changes nothing.
  ///
  /// 409 while the day isn't running; 400 for an unknown location or times
  /// that can't be.
  Future<MyActivity> registerTrip(int userId, TripRequest request) async {
    final left = _toSecond(request.leftAt), arrived = _toSecond(request.arrivedAt);
    if (arrived.isAfter(_now().toUtc().add(_allowedClockSkew))) {
      throw const ApiException.validation(TripRequest.fieldArrivedAt, 'A trip can’t end in the future.');
    }
    if (!arrived.isAfter(left)) {
      throw const ApiException.validation(TripRequest.fieldArrivedAt, 'A trip ends after it starts.');
    }
    if (request.fromAddressId == request.toAddressId) {
      throw const ApiException.validation(TripRequest.fieldTo, 'A trip goes somewhere else.');
    }
    for (final (field, id) in [(TripRequest.fieldFrom, request.fromAddressId), (TripRequest.fieldTo, request.toAddressId)]) {
      final location = await _locations.find(_executor, id);
      if (location == null || !location.isActive) {
        throw ApiException.validation(field, 'This location is not recognised.');
      }
    }
    final day = (await _myDay.today(userId)).day;
    if (day == null || day.finish != null || (day.start == null && day.pending.isEmpty)) {
      throw const ApiException(409, ApiErrorCode.workdayNotRunning, 'Start the day first.');
    }
    final projects = await _projectsOf(_executor, userId);
    final atClient = _clientSite(projects, request.toAddressId);
    if (atClient == null && _clientSite(projects, request.fromAddressId) == null) return mine(userId);

    await _transactions.transaction((tx) async {
      await _writes.lockUser(tx, userId);
      final (from, to) = _todayBounds();
      final latest = (await _activities.between(tx, userId, from, to)).lastOrNull;
      // Already on Transport by their own switch: only the arrival is new.
      final travelling = latest?.typeName == ActivityRepository.transportType;
      if (latest != null && !latest.at.isBefore(travelling ? arrived : left)) return;
      Future<void> add(ActivityKind kind, DateTime at, int addressId) async {
        final typeId = await _typeOf(tx, kind);
        final id = await _activities.insert(tx, userId: userId, typeId: typeId, at: at, addressId: addressId);
        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.activitySwitched,
            actorUserId: userId,
            references: {
              EventLogReference.user: userId,
              EventLogReference.timeReg: id,
              EventLogReference.timeRegType: typeId,
              EventLogReference.address: addressId,
            },
          ),
        );
      }

      if (!travelling) await add(ActivityKind.transport, left, request.fromAddressId);
      await add(atClient == null ? ActivityKind.work : ActivityKind.clientOnSite, arrived, request.toAddressId);
    });
    return mine(userId);
  }

  /// Today's list: transports in a row are one line.
  Future<List<ActivityEntry>> _entries(int userId) async {
    final (from, to) = _todayBounds();
    return _lines.between(userId, from, to);
  }

  late final _lines = ActivityEntries(
    activities: _activities,
    projects: _projects,
    locations: _locations,
    kilometres: _kilometres,
    executor: _executor,
    clock: _clock,
  );

  /// Today's activities, each until the next one, the finish or now.
  Future<ActivityBreakdown> _breakdown(int userId) async {
    final (from, to) = _todayBounds();
    final rows = await _activities.between(_executor, userId, from, to);
    final today = await _myDay.today(userId);
    final day = today.day;
    final finish = day?.finish?.actual;
    final now = _now().toUtc();
    final last = finish != null && finish.isBefore(now) ? finish : now;
    // Time away replaces the break (D34); either is left out of every part,
    // so the parts add up to the day's total.
    final breakStart = today.breakStart, breakFinish = today.breakFinish;
    final away = (day?.awayMinutes ?? 0) > 0
        ? ActivityMinutes.timeAway(day)
        : [if (breakStart != null && breakFinish != null) (ActivityMinutes.minuteOf(breakStart), ActivityMinutes.minuteOf(breakFinish))];
    final projectNames = {for (final p in await _projects.list(_executor)) p.id: p.fullName};
    final perProject = <String, int>{};
    var client = 0, internal = 0, other = 0, transport = 0, trips = 0;
    for (final (i, row) in rows.indexed) {
      final end = i + 1 < rows.length ? rows[i + 1].at : last;
      final minutes = end.isAfter(row.at) ? ActivityMinutes.between(_clock, row.at, end, away) : 0;
      final project = projectNames[row.addressId];
      if (project != null && _kindOf(row.typeName) != ActivityKind.transport) {
        perProject[project] = (perProject[project] ?? 0) + minutes;
      }
      switch (_kindOf(row.typeName)) {
        case ActivityKind.clientOnSite || ActivityKind.clientInHouse:
          client += minutes;
        case ActivityKind.internal:
          internal += minutes;
        case ActivityKind.work:
          other += minutes;
        case ActivityKind.transport:
          transport += minutes;
          if (i == 0 || _kindOf(rows[i - 1].typeName) != ActivityKind.transport) trips++;
      }
    }
    final distance = await _kilometres.ofDay(rows);
    return ActivityBreakdown(
      clientMinutes: client,
      internalMinutes: internal,
      otherMinutes: other,
      transportMinutes: transport,
      trips: trips,
      distanceMetres: distance.metres,
      tripsWithoutDistance: distance.unknown,
      projects: [
        for (final MapEntry(:key, :value) in perProject.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          if (value > 0) ProjectMinutes(name: key, minutes: value),
      ],
    );
  }

  /// Stores what the day starts on, in the transaction of the start: the
  /// project used last (D38), else plain work at [addressId] so a trip later
  /// knows where it left from (D40). Nothing to store without either, or while
  /// the activity rows are missing from the Lists page: the start itself
  /// never fails for it.
  Future<void> dayStarted(SqlExecutor tx, int userId, DateTime at, int? addressId) async {
    final project = (await _projectsOf(tx, userId)).where((p) => p.isRecent).firstOrNull;
    if ((project == null && addressId == null) || !await _typesReady(tx)) return;
    if (project == null) {
      await _activities.insert(tx, userId: userId, typeId: await _typeOf(tx, ActivityKind.work), at: at, addressId: addressId);
      return;
    }
    final kind = !project.isClient
        ? ActivityKind.internal
        : addressId == null || addressId == project.id
        ? ActivityKind.clientOnSite
        : ActivityKind.clientInHouse;
    await _activities.insert(tx, userId: userId, typeId: await _typeOf(tx, kind), at: at, addressId: project.id);
  }

  /// Every active project, the ones [userId] used last first.
  Future<List<MyProject>> _projectsOf(SqlExecutor executor, int userId) async {
    final workshops = {
      for (final w in await _locations.all(executor, withProjects: false)) ?ProjectRepository.coordinatesOf(w.point): w.name,
    };
    return [
      for (final row in await _projects.list(executor, activeOnly: true, userId: userId))
        MyProject(
          id: row.id,
          name: row.fullName,
          isClient: row.hasArea,
          placeName: ProjectService.summaryOf(row, workshops).placeName,
          lastUsed: row.lastUsed,
        ),
    ];
  }

  /// Every activity row exists (the Lists page).
  Future<bool> _typesReady(SqlExecutor executor) async {
    for (final name in _typeNames.values) {
      if (await _writes.typeId(executor, name) == null) return false;
    }
    return true;
  }

  Future<CurrentActivity?> _current(int userId, List<MyProject> projects, List<MyCompany> companies) async {
    final (from, to) = _todayBounds();
    final latest = (await _activities.between(_executor, userId, from, to)).lastOrNull;
    if (latest == null) return null;
    return CurrentActivity(
      kind: _kindOf(latest.typeName),
      since: latest.at,
      project: projects.where((p) => p.id == latest.addressId).firstOrNull,
      company: _defaultCompany(companies),
    );
  }

  /// The active client project whose site is [addressId].
  static MyProject? _clientSite(List<MyProject> projects, int addressId) =>
      projects.where((p) => p.isClient && p.id == addressId).firstOrNull;

  static MyCompany? _defaultCompany(List<MyCompany> companies) =>
      companies.where((c) => c.isDefault).firstOrNull ?? (companies.length == 1 ? companies.single : null);

  static DateTime _toSecond(DateTime at) => DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch ~/ 1000 * 1000, isUtc: true);

  static MyProject _active(List<MyProject> projects, int projectId) =>
      projects.where((p) => p.id == projectId).firstOrNull ??
      (throw const ApiException.validation(SwitchActivityRequest.fieldProject, 'This project can’t be chosen.'));

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
    return (_clock.utcOf(DateTime(local.year, local.month, local.day)), _clock.utcOf(DateTime(local.year, local.month, local.day + 1)));
  }
}

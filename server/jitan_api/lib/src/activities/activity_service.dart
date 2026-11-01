import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../locations/location_repository.dart';
import '../time_records/my_day_service.dart';
import '../time_registration/time_registration_write_repository.dart';
import '../time_registration/workplace_clock.dart';
import 'activity_repository.dart';
import 'trip_kilometres.dart';

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
    required this._locations,
    required this._kilometres,
    required this._audit,
    required this._transactions,
    required this._executor,
    required this._clock,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ActivityRepository _activities;
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
      breakdown: await _breakdown(userId),
      today: await _entries(userId, projects),
      projects: [for (final p in projects) p.project],
      companies: companies,
    );
  }

  /// 409 while the day isn't running; 400 for a project that isn't theirs or
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
    final projects = await _activities.projects(_executor, userId);
    final atClient = _clientProjectAt(projects, request.toAddressId);
    final project = atClient ?? _clientProjectAt(projects, request.fromAddressId);
    if (project == null && !_hasClientProject(projects, request.toAddressId, request.fromAddressId)) {
      return mine(userId);
    }
    final companies = await _activities.companies(_executor, userId);
    final companyId = project?.companyId ?? _defaultCompany(companies)?.id;

    await _transactions.transaction((tx) async {
      await _writes.lockUser(tx, userId);
      final (from, to) = _todayBounds();
      final latest = (await _activities.between(tx, userId, from, to)).lastOrNull;
      // Already on Transport by their own switch: only the arrival is new.
      final travelling = latest?.typeName == ActivityRepository.transportType;
      if (latest != null && !latest.at.isBefore(travelling ? arrived : left)) return;
      Future<void> add(ActivityKind kind, DateTime at, int addressId, MyProject? forProject) async {
        final typeId = await _typeOf(tx, kind);
        final id = await _activities.insert(
          tx,
          userId: userId,
          typeId: typeId,
          at: at,
          projectId: forProject?.id,
          companyId: companyId,
          addressId: addressId,
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
              EventLogReference.address: addressId,
              EventLogReference.project: ?forProject?.id,
              EventLogReference.company: ?companyId,
            },
          ),
        );
      }

      if (!travelling) await add(ActivityKind.transport, left, request.fromAddressId, project);
      await add(atClient == null ? ActivityKind.work : ActivityKind.clientOnSite, arrived, request.toAddressId, atClient);
    });
    return mine(userId);
  }

  /// Whether [groupId]'s travel counts as work (D39); 404 for no such group.
  Future<GroupTravel> groupTravel(int groupId) async => GroupTravel(
    available: true,
    travelIsWork: await _activities.groupTravel(_executor, groupId) ?? (throw _noGroup()),
  );

  /// Changes it, audited; nothing happens when it is already so.
  Future<GroupTravel> setGroupTravel(int actorUserId, int groupId, {required bool travelIsWork}) async {
    await _transactions.transaction((tx) async {
      final current = await _activities.groupTravel(tx, groupId) ?? (throw _noGroup());
      if (current == travelIsWork) return;
      await _activities.setGroupTravel(tx, groupId, travelIsWork: travelIsWork);
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.groupTravelChanged,
          actorUserId: actorUserId,
          references: {EventLogReference.group: groupId},
        ),
      );
    });
    return GroupTravel(available: true, travelIsWork: travelIsWork);
  }

  static ApiException _noGroup() => const ApiException.notFound('No such group.');

  /// Today's list: transports in a row are one line.
  Future<List<ActivityEntry>> _entries(int userId, List<AssignedProject> projects) async {
    final (from, to) = _todayBounds();
    final rows = await _activities.between(_executor, userId, from, to);
    if (rows.isEmpty) return const [];
    final names = {for (final p in projects) p.project.id: p.project.name};
    final places = {for (final l in await _locations.all(_executor)) l.id: l.name};
    final trips = await _kilometres.distancesOf(rows);
    bool isTransport(int i) => rows[i].typeName == ActivityRepository.transportType;
    var trip = 0;
    return [
      for (final (i, row) in rows.indexed)
        if (!isTransport(i))
          ActivityEntry(
            timeLocal: _time(row.at),
            kind: _kindOf(row.typeName),
            projectName: names[row.projectId],
            placeName: places[row.addressId ?? row.projectAddressId],
          )
        else if (i == 0 || !isTransport(i - 1))
          () {
            final (trip: to, :metres) = trips[trip++];
            return ActivityEntry(
              timeLocal: _time(row.at),
              kind: ActivityKind.transport,
              projectName: names[row.projectId],
              placeName: places[to.to],
              metres: metres,
            );
          }(),
    ];
  }

  String _time(DateTime at) {
    final local = _clock.wallClockOf(at);
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Today's activities, each until the next one, the finish or now.
  Future<ActivityBreakdown> _breakdown(int userId) async {
    final (from, to) = _todayBounds();
    final rows = await _activities.between(_executor, userId, from, to);
    final finish = (await _myDay.today(userId)).day?.finish?.actual;
    final now = _now().toUtc();
    final last = finish != null && finish.isBefore(now) ? finish : now;
    var client = 0, internal = 0, other = 0, transport = 0, trips = 0;
    for (final (i, row) in rows.indexed) {
      final end = i + 1 < rows.length ? rows[i + 1].at : last;
      final minutes = end.isAfter(row.at) ? end.difference(row.at).inMinutes : 0;
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
    );
  }

  /// Stores what the day starts on, and at [addressId] when that is known, in
  /// the transaction of the start. A terminal says the company with
  /// [companyId]. Nothing to store without a project or a company.
  Future<void> dayStarted(SqlExecutor tx, int userId, DateTime at, int? addressId, int? companyId) async {
    final projects = await _activities.projects(tx, userId);
    final companies = await _activities.companies(tx, userId);
    final project = _defaultProject(projects);
    final company = _defaultCompany(companies);
    if (project == null && company == null && companyId == null) return;
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
      companyId: project?.companyId ?? companyId ?? company?.id,
      addressId: addressId,
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

  /// The client project of theirs at [addressId]. Several there: the one
  /// their default rule picks (D38), which may be none.
  static MyProject? _clientProjectAt(List<AssignedProject> projects, int addressId) => _defaultProject([
    for (final p in projects)
      if (p.addressId == addressId && p.project.isClient) p,
  ]);

  static bool _hasClientProject(List<AssignedProject> projects, int to, int from) => projects.any(
    (p) => p.project.isClient && p.project.isCurrent && (p.addressId == to || p.addressId == from),
  );

  static MyCompany? _defaultCompany(List<MyCompany> companies) =>
      companies.where((c) => c.isDefault).firstOrNull ?? (companies.length == 1 ? companies.single : null);

  static DateTime _toSecond(DateTime at) =>
      DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch ~/ 1000 * 1000, isUtc: true);

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

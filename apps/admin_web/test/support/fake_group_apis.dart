import 'dart:async';

import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Stand-in for [GroupManagementApi]: an in-memory list of groups; every
/// call is recorded. [failNext] makes the next write fail.
class FakeGroupManagementApi implements GroupManagementApi {
  FakeGroupManagementApi([List<GroupOverview>? groups]) : groups = [...?groups];

  final List<GroupOverview> groups;
  final calls = <String>[];
  ApiClientException? failNext;

  /// Holds [overview] until the test completes it (loading state).
  Completer<void>? holdOverview;

  @override
  Future<List<GroupOverview>> overview() async {
    calls.add('overview');
    if (holdOverview case final hold?) await hold.future;
    return [...groups];
  }

  Future<GroupOverview> _write(String call, GroupOverview Function() change) async {
    calls.add(call);
    if (failNext case final failure?) {
      failNext = null;
      throw failure;
    }
    return change();
  }

  GroupOverview _replace(int id, GroupOverview Function(GroupOverview) change) {
    final index = groups.indexWhere((g) => g.id == id);
    return groups[index] = change(groups[index]);
  }

  /// The last Create group request.
  CreateGroupRequest? created;

  @override
  Future<GroupOverview> create(CreateGroupRequest request) =>
      _write('create ${request.name} ${request.employeeIds.join(',')}', () {
        created = request;
        final group = GroupOverview(
          id: 100 + groups.length,
          name: request.name,
          isActive: true,
          employeeCount: request.employeeIds.length,
        );
        groups.add(group);
        return group;
      });

  @override
  Future<GroupOverview> rename(int groupId, String name) => _write(
    'rename $groupId $name',
    () => _replace(groupId, (g) => GroupOverview(id: g.id, name: name, isActive: g.isActive, employeeCount: g.employeeCount)),
  );

  @override
  Future<GroupOverview> deactivate(int groupId) => _write(
    'deactivate $groupId',
    () => _replace(groupId, (g) => GroupOverview(id: g.id, name: g.name, isActive: false, employeeCount: g.employeeCount)),
  );

  @override
  Future<GroupOverview> reactivate(int groupId) => _write(
    'reactivate $groupId',
    () => _replace(groupId, (g) => GroupOverview(id: g.id, name: g.name, isActive: true, employeeCount: g.employeeCount)),
  );
}

/// Stand-in for [GroupMembersApi]: members per group and a pool of
/// employees to add; every call is recorded.
class FakeGroupMembersApi implements GroupMembersApi {
  /// Members per group id.
  final byGroup = <int, List<GroupMember>>{};
  final List<GroupMember> pool = [];
  final calls = <String>[];
  ApiClientException? failNext;

  @override
  Future<List<GroupMember>> members(int groupId) async {
    calls.add('members $groupId');
    return [...?byGroup[groupId]];
  }

  @override
  Future<List<GroupMember>> candidates(int? groupId, {String? search}) async {
    calls.add('candidates ${groupId ?? 'new'} ${search ?? ''}'.trim());
    final inGroup = {for (final m in byGroup[groupId] ?? const <GroupMember>[]) m.id};
    return [
      for (final e in pool)
        if (!inGroup.contains(e.id) && (search == null || e.displayName.toLowerCase().contains(search.toLowerCase()))) e,
    ];
  }

  @override
  Future<List<GroupMember>> add(int groupId, List<int> userIds, {List<int> followIds = const []}) async {
    calls.add('add $groupId ${userIds.join(',')}${followIds.isEmpty ? '' : ' follow ${followIds.join(',')}'}');
    if (failNext case final failure?) {
      failNext = null;
      throw failure;
    }
    final list = byGroup.putIfAbsent(groupId, () => []);
    list.addAll(pool.where((e) => userIds.contains(e.id)));
    return [...list];
  }

  @override
  Future<List<GroupMember>> remove(int groupId, int userId) async {
    calls.add('remove $groupId $userId');
    byGroup[groupId]?.removeWhere((m) => m.id == userId);
    return [...?byGroup[groupId]];
  }
}

GroupOverview groupOverview(int id, String name, {bool active = true, int employees = 0}) =>
    GroupOverview(id: id, name: name, isActive: active, employeeCount: employees);

GroupMember member(
  int id,
  String first,
  String last,
  String code, {
  List<String> companies = const ['Almeco'],
  List<String> groups = const [],
  List<int> companyIds = const [7],
  int? hoursFromGroupId,
  String? hoursFromGroup,
}) => GroupMember(
  id: id,
  firstName: first,
  lastName: last,
  code: code,
  companies: companies,
  groups: groups,
  companyIds: companyIds,
  hoursFromGroupId: hoursFromGroupId,
  hoursFromGroup: hoursFromGroup,
);

/// Stand-in for [ScheduleSourceApi]: answers at once from [groups] /
/// [source]; [failSet] makes the next save fail.
class FakeScheduleSourceApi implements ScheduleSourceApi {
  List<GroupSummary> groups = const [];
  int? source;
  ApiClientException? failSet;

  /// `get 7/1`, `set 7/1 2`.
  final calls = <String>[];

  @override
  Future<ScheduleSourceResponse> get(int companyId, int userId) async {
    calls.add('get $companyId/$userId');
    return ScheduleSourceResponse(groups: groups, sourceGroupId: source);
  }

  @override
  Future<ScheduleSourceResponse> set(int companyId, int userId, int groupId) async {
    calls.add('set $companyId/$userId $groupId');
    if (failSet case final failure?) {
      failSet = null;
      throw failure;
    }
    source = groupId;
    return ScheduleSourceResponse(groups: groups, sourceGroupId: source);
  }
}

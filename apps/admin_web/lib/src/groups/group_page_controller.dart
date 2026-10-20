import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What a group's page is showing.
sealed class GroupPageState {
  const GroupPageState();
}

class GroupPageLoading extends GroupPageState {
  const GroupPageLoading();
}

class GroupPageLoaded extends GroupPageState {
  const GroupPageLoaded({required this.group, required this.members, required this.schedules});

  final GroupOverview group;
  final List<GroupMember> members;

  /// Every active group's schedule (the schedule wizard's choices); this
  /// group's is [schedule].
  final List<GroupSchedule> schedules;

  GroupSchedule? get schedule => schedules.where((s) => s.group.id == group.id).firstOrNull;
}

class GroupPageFailed extends GroupPageState {
  const GroupPageFailed(this.failure);

  final ApiClientException failure;
}

/// Loads one group's page: the group, its members from every company and
/// its schedule. The server decides everything; this only sequences calls.
class GroupPageController extends ChangeNotifier {
  GroupPageController({
    required this.groupId,
    required this.groupsApi,
    required this.membersApi,
    required this.schedulesApi,
  });

  final int groupId;
  final GroupManagementApi groupsApi;
  final GroupMembersApi membersApi;
  final SchedulesApi schedulesApi;

  GroupPageState _state = const GroupPageLoading();
  GroupPageState get state => _state;
  bool _disposed = false;

  Future<void> load() async {
    _emit(const GroupPageLoading());
    try {
      final group = (await groupsApi.overview()).where((g) => g.id == groupId).firstOrNull;
      if (group == null) {
        _emit(const GroupPageFailed(ApiClientException.server(404, ApiError(code: ApiErrorCode.notFound, message: 'No such group.'))));
        return;
      }
      final members = await membersApi.members(groupId);
      final schedules = await schedulesApi.groupSchedules();
      _emit(GroupPageLoaded(group: group, members: members, schedules: schedules));
    } on ApiClientException catch (failure) {
      _emit(GroupPageFailed(failure));
    }
  }

  /// Removes [member]; the failure, or `null` once the server confirmed
  /// (the page then reloads, as the group's schedule may have changed).
  Future<ApiClientException?> remove(GroupMember member) async {
    try {
      await membersApi.remove(groupId, member.id);
    } on ApiClientException catch (failure) {
      return failure;
    }
    await load();
    return null;
  }

  void _emit(GroupPageState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

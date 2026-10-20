import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// What the Employee groups screen is showing.
sealed class GroupsState {
  const GroupsState();
}

class GroupsLoading extends GroupsState {
  const GroupsLoading();
}

class GroupsLoaded extends GroupsState {
  const GroupsLoaded({required this.groups, required this.schedules});

  /// Every group, active or not, with its number of employees.
  final List<GroupOverview> groups;

  /// What the server found for each active group's schedule, by group id.
  final Map<int, GroupSchedule> schedules;
}

class GroupsFailed extends GroupsState {
  const GroupsFailed(this.failure);

  final ApiClientException failure;
}

/// The status filter of the groups list; `null` = all.
enum GroupStatusFilter { active, inactive }

/// Loads the groups and their schedules, and filters them for display.
/// Holds no group rules: the server validates every change.
class GroupsController extends ChangeNotifier {
  GroupsController({required this.groupsApi, required this.schedulesApi});

  final GroupManagementApi groupsApi;
  final SchedulesApi schedulesApi;

  GroupsState _state = const GroupsLoading();
  GroupsState get state => _state;

  String _search = '';
  String get search => _search;

  GroupStatusFilter? _status;
  GroupStatusFilter? get status => _status;

  int _latestRequest = 0;
  bool _disposed = false;

  List<GroupOverview> get visibleGroups => switch (_state) {
    GroupsLoaded(:final groups) => [
      for (final group in groups)
        if ((_search.isEmpty || group.name.toLowerCase().contains(_search.toLowerCase())) &&
            switch (_status) {
              null => true,
              GroupStatusFilter.active => group.isActive,
              GroupStatusFilter.inactive => !group.isActive,
            })
          group,
    ],
    _ => const [],
  };

  Future<void> load() async {
    final request = ++_latestRequest;
    _emit(const GroupsLoading());
    try {
      final groups = await groupsApi.overview();
      final schedules = await schedulesApi.groupSchedules();
      if (request == _latestRequest) {
        _emit(GroupsLoaded(groups: groups, schedules: {for (final s in schedules) s.group.id: s}));
      }
    } on ApiClientException catch (failure) {
      if (request == _latestRequest) _emit(GroupsFailed(failure));
    }
  }

  void updateSearch(String text) {
    _search = text.trim();
    _notify();
  }

  void updateStatus(GroupStatusFilter? status) {
    _status = status;
    _notify();
  }

  void _emit(GroupsState state) {
    _state = state;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

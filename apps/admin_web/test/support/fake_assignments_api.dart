import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Stand-in for [EmployeeAssignmentsApi]: options per kind ([byKind]); adds mark
/// options assigned unless [addFailure] is set.
class FakeEmployeeAssignmentsApi implements EmployeeAssignmentsApi {
  Map<AssignmentKind, List<AssignmentOption>> byKind = {};

  /// Thrown by [options] / [add] when set.
  ApiClientException? loadFailure;
  ApiClientException? addFailure;

  /// (companyId, userId, kind, ids) of every add.
  final adds = <(int, int, AssignmentKind, List<int>)>[];

  @override
  Future<AssignmentOptions> options(int companyId, int userId, AssignmentKind kind) async {
    if (loadFailure != null) throw loadFailure!;
    return AssignmentOptions(options: byKind[kind] ?? const []);
  }

  /// (companyId, userId, languageId) of every language change.
  final languageChanges = <(int, int, int)>[];

  @override
  Future<AssignmentOptions> setLanguage(int companyId, int userId, int languageId) async {
    languageChanges.add((companyId, userId, languageId));
    if (addFailure != null) throw addFailure!;
    byKind[AssignmentKind.language] = [
      for (final o in byKind[AssignmentKind.language] ?? const <AssignmentOption>[])
        AssignmentOption(id: o.id, name: o.name, code: o.code, isActive: o.isActive, isAssigned: o.id == languageId),
    ];
    return AssignmentOptions(options: byKind[AssignmentKind.language]!);
  }

  @override
  Future<AssignmentOptions> add(int companyId, int userId, AssignmentKind kind, List<int> ids) async {
    adds.add((companyId, userId, kind, ids));
    if (addFailure != null) throw addFailure!;
    byKind[kind] = [
      for (final o in byKind[kind] ?? const <AssignmentOption>[])
        AssignmentOption(id: o.id, name: o.name, isActive: o.isActive, isAssigned: o.isAssigned || ids.contains(o.id)),
    ];
    return AssignmentOptions(options: byKind[kind]!);
  }
}

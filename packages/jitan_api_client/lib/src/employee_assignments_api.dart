import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// What a "Manage employee assignments" tab assigns.
enum AssignmentKind {
  /// `tblUserCompany` (EMP-04).
  companies('companies'),

  /// `tblUserGroup` (EMP-05). Groups are universal across companies.
  groups('groups'),

  /// `tblUserLanguage` (EMP-06): one preferred language, replaced with
  /// [EmployeeAssignmentsApi.setLanguage] instead of added.
  language('language'),

  /// `tblUserCredGroup` (EMP-07): access roles, from the database.
  credentialGroups('credential-groups');

  const AssignmentKind(this.path);

  final String path;
}

/// `/companies/{id}/employees/{userId}/assignments/*`: HR/Admin "Manage
/// employee assignments". Companies and groups can also be removed (a soft
/// delete on the server); credential groups are only added.
class EmployeeAssignmentsApi {
  const EmployeeAssignmentsApi(this._transport);

  final ApiTransport _transport;

  /// Every option of [kind], with whether the employee has it.
  Future<AssignmentOptions> options(int companyId, int userId, AssignmentKind kind) async =>
      _decode(await _transport.getJson(_path(companyId, userId, kind)));

  /// Adds the options [ids]; returns the updated list.
  Future<AssignmentOptions> add(int companyId, int userId, AssignmentKind kind, List<int> ids) async =>
      _decode(await _transport.postJson(_path(companyId, userId, kind), AddAssignmentsRequest(ids: ids).toJson()));

  /// Removes assignment [id] of [kind] (companies or groups; soft delete on
  /// the server); returns the updated list.
  Future<AssignmentOptions> remove(int companyId, int userId, AssignmentKind kind, int id) async =>
      _decode(await _transport.deleteJson('${_path(companyId, userId, kind)}/$id'));

  /// Replaces the employee's preferred language; returns the updated list.
  Future<AssignmentOptions> setLanguage(int companyId, int userId, int languageId) async => _decode(
        await _transport.putJson(
          _path(companyId, userId, AssignmentKind.language),
          SetLanguageRequest(languageId: languageId).toJson(),
        ),
      );

  static String _path(int companyId, int userId, AssignmentKind kind) =>
      'companies/$companyId/employees/$userId/assignments/${kind.path}';

  static AssignmentOptions _decode(Map<String, Object?> json) {
    try {
      return AssignmentOptions.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Assignments: ${e.message}');
    }
  }
}

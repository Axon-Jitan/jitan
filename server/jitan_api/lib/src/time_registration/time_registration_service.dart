import 'dart:convert';

import 'package:jitan_models/jitan_models.dart';

import '../companies/company_repository.dart';
import '../database/sql_executor.dart';
import '../employees/employee_repository.dart';
import '../http/api_exception.dart';
import 'time_registration_repository.dart';

/// Read-only access to the registration stream (`tblTimeReg`): the raw
/// events, in order. No rounding, no work sessions, no interpretation of
/// types: those wait for GAP-01, GAP-02 and CLARIFY-02, and nothing derived
/// here is an official record.
class TimeRegistrationService {
  TimeRegistrationService({
    required this._registrations,
    required this._employees,
    required this._companies,
    required this._executor,
  });

  final TimeRegistrationRepository _registrations;
  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final SqlExecutor _executor;

  static const defaultLimit = 100;
  static const maxLimit = 500;

  /// `yyyy-MM-dd` or `yyyy-MM-ddTHH:mm[:ss]`, no offset: stored times have no
  /// timezone (GAP-02), so an offset could not be honoured.
  static final _wallClock = RegExp(r'^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2})?)?$');

  /// An employee's registrations, for HR/Admin working in [companyId]. The
  /// employee must belong to that company (404 otherwise): `tblTimeReg` has
  /// no company, so access goes through the employee's membership.
  Future<TimeRegistrationPage> forEmployee(int companyId, int userId, Map<String, String> query) async {
    if (!await _companies.exists(companyId) || await _employees.findInCompany(_executor, companyId, userId) == null) {
      throw ApiException.notFound('Employee $userId is not in company $companyId.');
    }
    return _page(userId, query);
  }

  /// The signed-in user's own registrations.
  Future<TimeRegistrationPage> mine(int userId, Map<String, String> query) => _page(userId, query);

  Future<TimeRegistrationPage> _page(int userId, Map<String, String> query) async {
    final from = _time(query, TimeRegistrationQuery.from);
    final to = _time(query, TimeRegistrationQuery.to);
    if (!from.isBefore(to)) {
      throw const ApiException.validation(TimeRegistrationQuery.to, '"to" must be after "from".');
    }
    final limit = _limit(query[TimeRegistrationQuery.limit]);
    final after = _decodeCursor(query[TimeRegistrationQuery.cursor]);

    // One extra row tells whether another page follows.
    final rows = await _registrations.listForUser(userId, from: from, to: to, limit: limit + 1, after: after);
    final page = rows.take(limit).toList();
    return TimeRegistrationPage(
      registrations: page,
      nextCursor: rows.length > limit ? _encodeCursor((timestamp: page.last.timestamp, id: page.last.id)) : null,
    );
  }

  static DateTime _time(Map<String, String> query, String field) {
    final raw = query[field]?.trim() ?? '';
    final parsed = _wallClock.hasMatch(raw) ? DateTime.tryParse(raw) : null;
    if (parsed == null) {
      throw ApiException.validation(field, '"$field" is required as yyyy-MM-dd or yyyy-MM-ddTHH:mm[:ss], without timezone.');
    }
    return parsed;
  }

  static int _limit(String? raw) {
    if (raw == null) return defaultLimit;
    final value = int.tryParse(raw);
    if (value == null || value < 1 || value > maxLimit) {
      throw const ApiException.validation(TimeRegistrationQuery.limit, '"limit" must be between 1 and $maxLimit.');
    }
    return value;
  }

  /// Opaque to clients: base64url of "timestamp|id".
  static String _encodeCursor(TimeRegistrationPosition position) =>
      base64Url.encode(utf8.encode('${position.timestamp.toIso8601String()}|${position.id}'));

  static TimeRegistrationPosition? _decodeCursor(String? raw) {
    if (raw == null) return null;
    try {
      final [timestamp, id] = utf8.decode(base64Url.decode(raw)).split('|');
      return (timestamp: DateTime.parse(timestamp), id: int.parse(id));
    } on Object {
      throw const ApiException.validation(TimeRegistrationQuery.cursor, 'Unknown cursor; start again without one.');
    }
  }
}

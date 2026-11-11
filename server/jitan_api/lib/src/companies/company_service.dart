import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'company_repository.dart';

/// Company use cases: the list, and adding, renaming, deactivating and
/// reactivating a company (Figma `1524:*`). IT's database starts empty, so HR
/// adds the companies in Jitan; a company holds only its name.
class CompanyService {
  const CompanyService(this._companies, {this._transactions, this._audit = const AuditLogRepository()});

  final CompanyRepository _companies;

  /// `null` where only the list is served (no writes).
  final TransactionRunner? _transactions;
  final AuditLogRepository _audit;

  /// Longest accepted search text. Longer input is rejected, not truncated.
  static const maxSearchLength = 100;

  /// Lists non-deleted companies, optionally filtered by name.
  /// Blank [search] means no filter.
  Future<List<CompanySummary>> listCompanies({String? search}) {
    final term = search?.trim() ?? '';
    if (term.length > maxSearchLength) {
      throw const ApiException.badRequest(
        'Search text must be at most $maxSearchLength characters.',
      );
    }
    return _companies.listCompanies(nameContains: term.isEmpty ? null : term);
  }

  /// A new, active company. 400 for an empty or too long name; 409 when the
  /// name is taken, ignoring capitals and accents.
  Future<CompanySummary> create(int actorUserId, CompanyRequest request) async {
    final name = _validName(request);
    final id = await _write(name, (tx) async {
      if (await _companies.nameTaken(tx, name)) throw _nameTaken(name);
      final id = await _companies.insert(tx, name);
      await _record(tx, AuditEventType.companyCreated, actorUserId, id);
      return id;
    });
    return find(id);
  }

  /// The same name again changes nothing. 404 for an unknown company.
  Future<CompanySummary> rename(int actorUserId, int companyId, CompanyRequest request) async {
    final name = _validName(request);
    await _write(name, (tx) async {
      final current = await _lock(tx, companyId);
      if (current.name == name) return;
      if (await _companies.nameTaken(tx, name, exceptId: companyId)) throw _nameTaken(name);
      await _companies.rename(tx, companyId, name);
      await _record(tx, AuditEventType.companyRenamed, actorUserId, companyId);
    });
    return find(companyId);
  }

  /// Switching a company off keeps it and everything in it; it shows as
  /// Inactive. The same state again changes nothing.
  Future<CompanySummary> setActive(int actorUserId, int companyId, {required bool active}) async {
    await _runner.transaction((tx) async {
      final current = await _lock(tx, companyId);
      if (current.active == active) return;
      await _companies.setActive(tx, companyId, active: active);
      await _record(tx, active ? AuditEventType.companyReactivated : AuditEventType.companyDeactivated, actorUserId, companyId);
    });
    return find(companyId);
  }

  Future<CompanySummary> find(int companyId) async =>
      await _companies.find(companyId) ?? (throw ApiException.notFound('Company $companyId does not exist.'));

  TransactionRunner get _runner => _transactions ?? (throw StateError('CompanyService was built without transactions.'));

  Future<({String name, bool active})> _lock(SqlExecutor tx, int companyId) async =>
      await _companies.lock(tx, companyId) ?? (throw ApiException.notFound('Company $companyId does not exist.'));

  static String _validName(CompanyRequest request) {
    final name = request.trimmed().name;
    if (name.isEmpty) throw const ApiException.validation(CompanyRequest.fieldName, 'Give the company a name.');
    if (name.length > CompanyRequest.maxNameLength) {
      throw const ApiException.validation(
        CompanyRequest.fieldName,
        'A company name can be at most ${CompanyRequest.maxNameLength} characters.',
      );
    }
    return name;
  }

  /// A name in use is checked first; the database still catches a race.
  Future<T> _write<T>(String name, Future<T> Function(SqlExecutor tx) action) async {
    try {
      return await _runner.transaction(action);
    } on DatabaseQueryException catch (e) {
      if (e.isDuplicateKey) throw _nameTaken(name);
      if (e.isValueTooLong) throw const ApiException.badRequest('A value is longer than allowed.');
      rethrow;
    }
  }

  static ApiException _nameTaken(String name) => ApiException(
    409,
    ApiErrorCode.duplicateCompanyName,
    'A company named "$name" already exists.',
    field: CompanyRequest.fieldName,
  );

  Future<void> _record(SqlExecutor tx, AuditEventType type, int actorUserId, int companyId) => _audit.record(
    tx,
    AuditEvent(type: type, actorUserId: actorUserId, references: {EventLogReference.company: companyId}),
  );
}

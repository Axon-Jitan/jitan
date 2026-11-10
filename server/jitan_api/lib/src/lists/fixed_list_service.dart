import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'fixed_list_catalog.dart';
import 'fixed_list_repository.dart';

/// The Lists page (Figma `1510:2`): which entries Jitan reads by name, which
/// are missing, and adding exactly those. Nothing else is added and nothing
/// is renamed: the code looks them up by these names. Each added entry is
/// audited in the same transaction.
class FixedListService {
  FixedListService({required this._lists, required this._audit, required this._transactions, required this._executor});

  final FixedListRepository _lists;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;

  Future<FixedListOverview> overview() async => FixedListOverview(
    lists: [
      for (final kind in FixedListKind.values) _summary(kind, await _lists.names(_executor, FixedListCatalog.of(kind))),
    ],
  );

  Future<FixedListDetail> detail(FixedListKind kind) async =>
      _detail(kind, await _lists.names(_executor, FixedListCatalog.of(kind)));

  /// Adds what [kind] is missing; nothing when it is complete.
  Future<FixedListDetail> addMissing(int actorUserId, FixedListKind kind) async {
    final list = FixedListCatalog.of(kind);
    if (!list.addable) throw const ApiException.validation('kind', 'This list is added to elsewhere.');
    await _transactions.transaction((tx) => _addMissing(tx, actorUserId, list));
    return detail(kind);
  }

  /// "Add what's missing": every list Jitan adds to, in one transaction.
  Future<FixedListOverview> addAllMissing(int actorUserId) async {
    await _transactions.transaction((tx) async {
      for (final kind in FixedListKind.values) {
        final list = FixedListCatalog.of(kind);
        if (list.addable) await _addMissing(tx, actorUserId, list);
      }
    });
    return overview();
  }

  Future<void> _addMissing(SqlExecutor tx, int actorUserId, FixedListTable list) async {
    final present = await _lists.names(tx, list, lock: true);
    for (final name in list.required) {
      if (present.contains(name)) continue;
      final id = await _lists.insert(tx, list, name);
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.listEntryAdded,
          actorUserId: actorUserId,
          references: {?list.reference: id},
        ),
      );
    }
  }

  static FixedListSummary _summary(FixedListKind kind, Set<String> present) {
    final list = FixedListCatalog.of(kind);
    return FixedListSummary(
      kind: kind,
      entries: present.length,
      required: list.required.length,
      missing: list.required.where((name) => !present.contains(name)).length,
    );
  }

  static FixedListDetail _detail(FixedListKind kind, Set<String> present) {
    final list = FixedListCatalog.of(kind);
    final required = list.required.toSet();
    return FixedListDetail(
      kind: kind,
      entries: [
        for (final name in list.required) FixedListEntry(name: name, present: present.contains(name), required: true),
        for (final name in present.where((n) => !required.contains(n)).toList()..sort())
          FixedListEntry(name: name, present: true, required: false),
      ],
    );
  }
}

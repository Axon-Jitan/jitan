import '../database/sql_executor.dart';
import 'fixed_list_catalog.dart';

/// Data access for the fixed lists. Every table and column name comes from
/// [FixedListCatalog] (fixed strings); every value is a bound parameter.
class FixedListRepository {
  const FixedListRepository();

  /// The names of the list's usable rows (active and not marked for deletion
  /// where the table has those columns). With [lock], the rows are locked for
  /// the rest of the transaction, so two adds don't both insert.
  Future<Set<String>> names(SqlExecutor executor, FixedListTable list, {bool lock = false}) async {
    final usable = list.activeColumn == null ? '' : ' WHERE ${list.activeColumn} = 1 AND ${list.mfdColumn} = 0';
    final rows = await executor.query('SELECT ${list.nameColumn} AS name FROM ${list.table}$usable${lock ? ' FOR UPDATE' : ''}');
    return {for (final row in rows) row.readString('name')};
  }

  /// Adds an active entry named [name] and returns its id.
  Future<int> insert(SqlExecutor tx, FixedListTable list, String name) async {
    final flags = list.activeColumn == null ? '' : ', ${list.activeColumn}, ${list.mfdColumn}';
    final values = list.activeColumn == null ? '' : ', 1, 0';
    return (await tx.execute(
      'INSERT INTO ${list.table} (${list.nameColumn}$flags) VALUES (:name$values)',
      {'name': name},
    )).lastInsertId;
  }
}

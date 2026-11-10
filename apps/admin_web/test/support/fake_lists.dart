import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Stand-in for [FixedListsApi]: terminal kinds and the kinds of place miss
/// entries until added; every call is recorded.
class FakeListsApi implements FixedListsApi {
  final calls = <String>[];
  final _missing = <FixedListKind, List<String>>{
    FixedListKind.terminalKinds: ['Office terminal', 'Vehicle terminal'],
    FixedListKind.placeKinds: ['Project location'],
  };

  static const _required = {
    FixedListKind.registrationTypes: 15,
    FixedListKind.scheduleTypes: 3,
    FixedListKind.days: 7,
    FixedListKind.placeKinds: 1,
    FixedListKind.terminalKinds: 2,
    FixedListKind.auditNames: 47,
  };

  FixedListSummary _summary(FixedListKind kind) {
    final required = _required[kind] ?? 0;
    final missing = _missing[kind]?.length ?? 0;
    return FixedListSummary(kind: kind, entries: required == 0 ? 3 : required - missing, required: required, missing: missing);
  }

  @override
  Future<FixedListOverview> overview() async => FixedListOverview(lists: [for (final kind in FixedListKind.values) _summary(kind)]);

  @override
  Future<FixedListDetail> detail(FixedListKind kind) async => FixedListDetail(
    kind: kind,
    entries: [
      for (final name in _missing[kind] ?? const <String>[]) FixedListEntry(name: name, present: false, required: true),
      if (kind == FixedListKind.days) const FixedListEntry(name: 'Monday', present: true, required: true),
    ],
  );

  @override
  Future<FixedListDetail> addMissing(FixedListKind kind) async {
    calls.add('add ${kind.wireName}');
    final added = _missing.remove(kind) ?? const [];
    return FixedListDetail(kind: kind, entries: [for (final name in added) FixedListEntry(name: name, present: true, required: true)]);
  }

  @override
  Future<FixedListOverview> addAllMissing() async {
    calls.add('add all');
    _missing.clear();
    return overview();
  }
}

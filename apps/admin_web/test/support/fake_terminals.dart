import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

const office = TerminalTypeChoice(id: 1, name: 'Office terminal');
const vehicle = TerminalTypeChoice(id: 2, name: 'Vehicle terminal');

Terminal officeTerminal({
  int id = 1,
  String name = 'Almeco Reception',
  TerminalStatus status = TerminalStatus.online,
  DateTime? lastSeen,
  DateTime? lastScan,
  String? connectionTag = 'tag-1',
}) => Terminal(
  id: id,
  name: name,
  type: office,
  serialNumber: 'R9TW40-$id',
  status: status,
  lastSeen: lastSeen,
  lastScan: lastScan,
  connectionTag: connectionTag,
);

/// Stand-in for [TerminalsApi].
class FakeTerminalsApi implements TerminalsApi {
  List<Terminal> terminals = [];
  ApiClientException? fail;
  final created = <TerminalRequest>[];
  final updated = <(int, TerminalRequest)>[];
  final calls = <String>[];

  /// What `find` answers while the dialog waits for the tablet.
  Terminal? found;

  /// When the next pairing QR expires.
  DateTime qrExpires = DateTime.now().toUtc().add(const Duration(minutes: 10));

  @override
  Future<TerminalOptions> options() async => const TerminalOptions(types: [office, vehicle], vehicleTypeIds: [2]);

  @override
  Future<List<Terminal>> list() async {
    if (fail case final failure?) throw failure;
    return terminals;
  }

  @override
  Future<Terminal> find(int terminalId) async =>
      found ?? terminals.firstWhere((t) => t.id == terminalId);

  @override
  Future<Terminal> create(TerminalRequest request) async {
    if (fail case final failure?) throw failure;
    created.add(request);
    final terminal = officeTerminal(id: 9, name: request.name, status: TerminalStatus.notConnected, connectionTag: null);
    terminals = [...terminals, terminal];
    return terminal;
  }

  @override
  Future<Terminal> update(int terminalId, TerminalRequest request) async {
    updated.add((terminalId, request));
    return terminals.firstWhere((t) => t.id == terminalId);
  }

  @override
  Future<Terminal> deactivate(Terminal terminal) async {
    calls.add('deactivate ${terminal.id}');
    return _replace(officeTerminal(id: terminal.id, name: terminal.name, status: TerminalStatus.inactive));
  }

  @override
  Future<Terminal> reactivate(Terminal terminal) async {
    calls.add('reactivate ${terminal.id}');
    return _replace(officeTerminal(id: terminal.id, name: terminal.name));
  }

  Terminal _replace(Terminal changed) {
    terminals = [for (final t in terminals) t.id == changed.id ? changed : t];
    return changed;
  }

  @override
  Future<TemporaryQrResponse> pairingQr(Terminal terminal) async {
    calls.add('qr ${terminal.id}');
    return TemporaryQrResponse(qrCode: 'pairing-code', purpose: TemporaryQrPurpose.terminalPairing, expiresAt: qrExpires);
  }
}

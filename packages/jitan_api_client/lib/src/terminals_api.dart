import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin managing terminals.
class TerminalsApi {
  const TerminalsApi(this._transport);

  final ApiTransport _transport;

  Future<TerminalOptions> options() async {
    final json = await _transport.getJson('terminal-options');
    try {
      return TerminalOptions.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Terminal options: ${e.message}');
    }
  }

  /// Every terminal: they are shared by every company.
  Future<List<Terminal>> list() async {
    final json = await _transport.getJson('terminals');
    try {
      return TerminalListResponse.fromJson(json).terminals;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Terminals: ${e.message}');
    }
  }

  Future<Terminal> find(int terminalId) async => _terminal(await _transport.getJson('terminals/$terminalId'));

  Future<Terminal> create(TerminalRequest request) async => _terminal(await _transport.postJson('terminals', request.toJson()));

  Future<Terminal> update(int terminalId, TerminalRequest request) async =>
      _terminal(await _transport.putJson('terminals/$terminalId', request.toJson()));

  Future<Terminal> deactivate(Terminal terminal) async => _action(terminal, 'deactivate');

  Future<Terminal> reactivate(Terminal terminal) async => _action(terminal, 'reactivate');

  Future<void> remove(Terminal terminal) async {
    await _transport.postJson('terminals/${terminal.id}/remove', const {});
  }

  /// A new temporary QR to connect a tablet; the previous one stops working.
  Future<TemporaryQrResponse> pairingQr(Terminal terminal) async {
    final json = await _transport.postJson('terminals/${terminal.id}/pairing-qr', const {});
    try {
      return TemporaryQrResponse.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Pairing QR: ${e.message}');
    }
  }

  Future<Terminal> _action(Terminal terminal, String action) async =>
      _terminal(await _transport.postJson('terminals/${terminal.id}/$action', const {}));

  static Terminal _terminal(Map<String, Object?> json) {
    try {
      return Terminal.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Terminal: ${e.message}');
    }
  }
}

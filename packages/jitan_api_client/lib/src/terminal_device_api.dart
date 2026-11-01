import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// What the Jitan Terminal tablet itself calls. The transport's access token
/// is the tablet's own secret, not a person's session.
class TerminalDeviceApi {
  const TerminalDeviceApi(this._transport);

  final ApiTransport _transport;

  Future<TerminalPairResponse> pair(TerminalPairRequest request) async {
    final json = await _transport.postJson('terminal/pair', request.toJson());
    try {
      return TerminalPairResponse.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Pairing: ${e.message}');
    }
  }

  /// The regular check-in: says what this tablet is and whether it can scan.
  Future<TerminalInfo> me() async {
    final json = await _transport.getJson('terminal/me');
    try {
      return TerminalInfo.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Terminal: ${e.message}');
    }
  }

  Future<TerminalScanResult> scan(TerminalScanRequest request) async =>
      _result(await _transport.postJson('terminal/scan', request.toJson()));

  Future<TerminalScanResult> switchTo(TerminalSwitchRequest request) async =>
      _result(await _transport.postJson('terminal/switch', request.toJson()));

  static TerminalScanResult _result(Map<String, Object?> json) {
    try {
      return TerminalScanResult.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Scan: ${e.message}');
    }
  }
}

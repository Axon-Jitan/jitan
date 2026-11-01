import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import 'terminal_device_service.dart';
import 'terminal_repository.dart';

/// The Jitan Terminal app. No session and no permission: a tablet proves
/// itself with its own secret (`Authorization: Bearer`), which
/// `TokenAuthenticationMiddleware` leaves alone under `/terminal/`.
///
/// - `POST /terminal/pair` (`TerminalPairRequest`): public, authorized by the
///   temporary pairing QR.
/// - `GET /terminal/me`: the tablet's regular check-in.
/// - `POST /terminal/scan` (`TerminalScanRequest`).
/// - `POST /terminal/switch` (`TerminalSwitchRequest`).
///
/// Every answer is `no-store`. With [_device] `null` (a database without the
/// proposed tables) all of this is 404.
class TerminalDeviceRoutes {
  const TerminalDeviceRoutes(this._device);

  final TerminalDeviceService? _device;

  Router get router => Router()
    ..post('/terminal/pair', _pair)
    ..get('/terminal/me', _me)
    ..post('/terminal/scan', _scan)
    ..post('/terminal/switch', _switch);

  TerminalDeviceService get _service => _device ?? (throw const ApiException.notFound('Terminals are not available.'));

  Future<Response> _pair(Request request) async {
    final body = await _read(request, TerminalPairRequest.fromJson);
    return _answer((await _service.pair(body)).toJson());
  }

  Future<Response> _me(Request request) async => _answer((await _service.seen(await _terminal(request))).toJson());

  Future<Response> _scan(Request request) async {
    final terminal = await _terminal(request);
    return _answer((await _service.scan(terminal, await _read(request, TerminalScanRequest.fromJson))).toJson());
  }

  Future<Response> _switch(Request request) async {
    final terminal = await _terminal(request);
    return _answer((await _service.switchTo(terminal, await _read(request, TerminalSwitchRequest.fromJson))).toJson());
  }

  Future<TerminalRow> _terminal(Request request) {
    final header = request.headers['authorization'];
    const scheme = 'bearer ';
    final token = header != null && header.toLowerCase().startsWith(scheme) ? header.substring(scheme.length).trim() : null;
    return _service.authenticate(token);
  }

  static Future<T> _read<T>(Request request, T Function(Map<String, Object?>) parse) async {
    try {
      return parse(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }

  static Response _answer(Map<String, Object?> body) =>
      jsonResponse(body).change(headers: const {'cache-control': 'no-store'});
}

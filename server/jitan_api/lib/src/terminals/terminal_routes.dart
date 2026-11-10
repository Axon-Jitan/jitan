import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'terminal_service.dart';

/// Terminals. Consumer: the HR/Admin Terminals page (Figma `1507:2` …). A
/// terminal is shared by every company (GAP-09), so these paths have no
/// company: the permission is checked without one.
///
/// - `GET /terminal-options`: the form's types.
/// - `GET /terminals` and `POST /terminals` (`TerminalRequest`, 201).
/// - `GET` and `PUT /terminals/{id}`.
/// - `POST /terminals/{id}/deactivate`, `/reactivate` and `/remove`.
/// - `POST /terminals/{id}/pairing-qr`: `no-store`, it is a credential.
class TerminalRoutes {
  const TerminalRoutes(this._authorizer, this._terminals);

  final Authorizer _authorizer;
  final TerminalService _terminals;

  static const _terminal = '/terminals/<terminalId|[0-9]+>';

  Router get router => Router()
    ..get('/terminal-options', _options)
    ..get('/terminals', _list)
    ..post('/terminals', _create)
    ..get(_terminal, _find)
    ..put(_terminal, _update)
    ..post('$_terminal/deactivate', _deactivate)
    ..post('$_terminal/reactivate', _reactivate)
    ..post('$_terminal/remove', _remove)
    ..post('$_terminal/pairing-qr', _pairingQr);

  Future<Response> _options(Request request) async {
    await _authorizer.require(request, Permission.viewTerminals);
    return jsonResponse((await _terminals.options()).toJson());
  }

  Future<Response> _list(Request request) async {
    await _authorizer.require(request, Permission.viewTerminals);
    return jsonResponse(TerminalListResponse(terminals: await _terminals.list()).toJson());
  }

  Future<Response> _create(Request request) async {
    final identity = await _authorizer.require(request, Permission.manageTerminals);
    return jsonResponse((await _terminals.create(identity.userId, await _body(request))).toJson(), statusCode: 201);
  }

  Future<Response> _find(Request request, String terminalId) async {
    await _authorizer.require(request, Permission.viewTerminals);
    return jsonResponse((await _terminals.find(_id(terminalId))).toJson());
  }

  Future<Response> _update(Request request, String terminalId) async {
    final identity = await _authorizer.require(request, Permission.manageTerminals);
    return jsonResponse((await _terminals.update(identity.userId, _id(terminalId), await _body(request))).toJson());
  }

  Future<Response> _deactivate(Request request, String terminalId) => _setActive(request, terminalId, active: false);

  Future<Response> _reactivate(Request request, String terminalId) => _setActive(request, terminalId, active: true);

  Future<Response> _setActive(Request request, String terminalId, {required bool active}) async {
    final identity = await _authorizer.require(request, Permission.manageTerminals);
    return jsonResponse((await _terminals.setActive(identity.userId, _id(terminalId), active: active)).toJson());
  }

  Future<Response> _remove(Request request, String terminalId) async {
    final identity = await _authorizer.require(request, Permission.manageTerminals);
    await _terminals.remove(identity.userId, _id(terminalId));
    return jsonResponse(const <String, Object?>{});
  }

  Future<Response> _pairingQr(Request request, String terminalId) async {
    final identity = await _authorizer.require(request, Permission.manageTerminals);
    final qr = await _terminals.pairingQr(identity.userId, _id(terminalId));
    return jsonResponse(qr.toJson()).change(headers: const {'cache-control': 'no-store'});
  }

  static int _id(String raw) => pathId(raw, 'No such terminal.');

  Future<TerminalRequest> _body(Request request) async {
    try {
      return TerminalRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }
}

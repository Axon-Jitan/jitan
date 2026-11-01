import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../auth/request_identity.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'terminal_service.dart';

/// Terminals. Consumer: the HR/Admin Terminals page.
///
/// - `GET /terminal-options`: the form's types.
/// - `GET /terminals`: every terminal where the viewer may see them, each
///   company checked on its own (ENGINEERING_RULES §28a.5).
/// - `POST /companies/{id}/terminals` (`TerminalRequest`, 201).
/// - `GET` and `PUT /companies/{id}/terminals/{terminalId}`: moving it to
///   another company needs the right in both.
/// - `PUT …/{terminalId}/scanning` (`TerminalScanningRequest`).
/// - `POST …/{terminalId}/deactivate`, `/reactivate` and `/remove`.
/// - `POST …/{terminalId}/pairing-qr`: `no-store`, it is a credential.
///
/// With [_terminals] `null` (a database without the proposed tables) all of
/// this is 404.
class TerminalRoutes {
  const TerminalRoutes(this._authorizer, this._terminals);

  final Authorizer _authorizer;
  final TerminalService? _terminals;

  static const _company = '/companies/<companyId|[0-9]+>/terminals';
  static const _terminal = '$_company/<terminalId|[0-9]+>';

  Router get router => Router()
    ..get('/terminal-options', _options)
    ..get('/terminals', _list)
    ..post(_company, _create)
    ..get(_terminal, _find)
    ..put(_terminal, _update)
    ..put('$_terminal/scanning', _scanning)
    ..post('$_terminal/deactivate', _deactivate)
    ..post('$_terminal/reactivate', _reactivate)
    ..post('$_terminal/remove', _remove)
    ..post('$_terminal/pairing-qr', _pairingQr);

  TerminalService get _service => _terminals ?? (throw const ApiException.notFound('Terminals are not available.'));

  Future<Response> _options(Request request) async {
    // 401 without an identity; the choices hold no company's data.
    request.identity;
    return jsonResponse((await _service.options()).toJson());
  }

  Future<Response> _list(Request request) async {
    request.identity;
    final terminals = await _service.list((id) => _authorizer.may(request, Permission.viewTerminals, companyId: id));
    return jsonResponse(TerminalListResponse(terminals: terminals).toJson());
  }

  Future<Response> _create(Request request, String companyId) async {
    final company = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.manageTerminals, companyId: company);
    final body = await _body(request);
    if (body.companyId != company) throw const ApiException.validation(TerminalRequest.fieldCompany, 'Choose a company.');
    return jsonResponse((await _service.create(identity.userId, body)).toJson(), statusCode: 201);
  }

  Future<Response> _find(Request request, String companyId, String terminalId) async {
    final company = _companyId(companyId);
    await _authorizer.require(request, Permission.viewTerminals, companyId: company);
    return jsonResponse((await _service.find(company, _terminalId(terminalId))).toJson());
  }

  Future<Response> _update(Request request, String companyId, String terminalId) async {
    final company = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.manageTerminals, companyId: company);
    final body = await _body(request);
    if (body.companyId != company) await _authorizer.require(request, Permission.manageTerminals, companyId: body.companyId);
    return jsonResponse((await _service.update(identity.userId, company, _terminalId(terminalId), body)).toJson());
  }

  Future<Response> _scanning(Request request, String companyId, String terminalId) async {
    final company = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.manageTerminals, companyId: company);
    final bool enabled;
    try {
      enabled = TerminalScanningRequest.fromJson(await readJsonObject(request)).enabled;
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    return jsonResponse((await _service.setScanning(identity.userId, company, _terminalId(terminalId), enabled: enabled)).toJson());
  }

  Future<Response> _deactivate(Request request, String companyId, String terminalId) =>
      _setActive(request, companyId, terminalId, active: false);

  Future<Response> _reactivate(Request request, String companyId, String terminalId) =>
      _setActive(request, companyId, terminalId, active: true);

  Future<Response> _setActive(Request request, String companyId, String terminalId, {required bool active}) async {
    final company = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.manageTerminals, companyId: company);
    return jsonResponse((await _service.setActive(identity.userId, company, _terminalId(terminalId), active: active)).toJson());
  }

  Future<Response> _remove(Request request, String companyId, String terminalId) async {
    final company = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.manageTerminals, companyId: company);
    await _service.remove(identity.userId, company, _terminalId(terminalId));
    return jsonResponse(const <String, Object?>{});
  }

  Future<Response> _pairingQr(Request request, String companyId, String terminalId) async {
    final company = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.manageTerminals, companyId: company);
    final qr = await _service.pairingQr(identity.userId, company, _terminalId(terminalId));
    return jsonResponse(qr.toJson()).change(headers: const {'cache-control': 'no-store'});
  }

  static int _companyId(String raw) => pathId(raw, 'No such company.');

  static int _terminalId(String raw) => pathId(raw, 'No such terminal.');

  Future<TerminalRequest> _body(Request request) async {
    try {
      return TerminalRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }
}

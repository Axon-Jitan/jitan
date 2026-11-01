import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import '../device/terminal_store.dart';
import 'terminal_view.dart';

final _log = Logger('terminal');

/// The tablet's whole flow, and no rules: the server decides whether a scan
/// checks in or out (D41), and nothing is kept for later (D42). QR values are
/// credentials: never logged.
class TerminalController extends ChangeNotifier {
  TerminalController({
    required this._api,
    required this._store,
    required this._setToken,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TerminalDeviceApi _api;
  final TerminalStore _store;

  /// Gives the API its secret; `null` once it is no longer valid.
  final ValueChanged<String?> _setToken;
  final DateTime Function() _clock;

  /// How long a result stays before the camera is back.
  static const resultFor = Duration(seconds: 5);
  static const hrNoteFor = Duration(seconds: 8);
  static const readyFor = Duration(seconds: 3);
  static const noteFor = Duration(seconds: 4);

  /// How often HR hears this tablet is alive.
  static const checkInEvery = Duration(minutes: 1);

  /// A code still in front of the camera isn't a new scan.
  static const sameCodeFor = Duration(seconds: 8);

  TerminalView _view = const Starting();
  TerminalView get view => _view;

  TerminalInfo? _terminal;
  TerminalInfo? get terminal => _terminal;

  Timer? _back;
  Timer? _checkIn;
  bool _busy = false;
  bool _disposed = false;
  String? _lastCode;
  DateTime? _lastCodeAt;

  bool get busy => _busy;

  Future<void> start() async {
    final token = await _store.token();
    if (token == null) return _show(const Connecting());
    _setToken(token);
    await _checkInNow();
    if (_view is Starting) _show(const Scanning());
    _startCheckIns();
  }

  void _startCheckIns() {
    _checkIn?.cancel();
    _checkIn = Timer.periodic(checkInEvery, (_) => _checkInNow());
  }

  Future<void> _checkInNow() async {
    try {
      _terminal = await _api.me();
      _notify();
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return _disconnected();
      _log.warning('The check-in failed: ${e.kind.name} ${e.statusCode ?? ''}');
    }
  }

  /// HR removed or reconnected this terminal.
  Future<void> _disconnected() async {
    _checkIn?.cancel();
    _back?.cancel();
    _terminal = null;
    _setToken(null);
    await _store.clearToken();
    _show(const Connecting());
  }

  /// Whatever the camera read on the current screen.
  Future<void> scanned(String code) async {
    if (_busy || _isRepeat(code)) return;
    _lastCode = code;
    _lastCodeAt = _clock();
    if (_view is Connecting) return _pair(code);
    if (_view is Scanning && (_terminal?.canScan ?? true)) return _scan(code);
  }

  bool _isRepeat(String code) {
    final at = _lastCodeAt;
    return code == _lastCode && at != null && _clock().difference(at) < sameCodeFor;
  }

  Future<void> _pair(String code) async {
    _setBusy(true);
    try {
      final paired = await _api.pair(
        TerminalPairRequest(qrCode: code, deviceId: await _store.deviceId(), deviceName: await _store.deviceName()),
      );
      await _store.saveToken(paired.token);
      _setToken(paired.token);
      _terminal = paired.terminal;
      _startCheckIns();
      _show(TabletReady(paired.terminal));
      _returnIn(readyFor);
    } on ApiClientException catch (e) {
      _show(Connecting(problem: _connectProblem(e)));
    } finally {
      _setBusy(false);
    }
  }

  static ConnectProblem _connectProblem(ApiClientException e) {
    if (e.kind == ApiFailureKind.network) return ConnectProblem.noConnection;
    return switch (e.error?.code) {
      ApiErrorCode.qrExpired || ApiErrorCode.qrAlreadyUsed => ConnectProblem.expired,
      _ => ConnectProblem.unreadable,
    };
  }

  Future<void> _scan(String code) async {
    _setBusy(true);
    try {
      final result = await _api.scan(TerminalScanRequest(qrCode: code, at: _clock().toUtc()));
      _show(Registered(result, code));
      _returnIn(resultFor);
    } on ApiClientException catch (e) {
      await _refused(e);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _refused(ApiClientException e) async {
    if (e.statusCode == 401) return _disconnected();
    switch (e.error?.code) {
      case ApiErrorCode.qrNotRecognised || ApiErrorCode.validationFailed || ApiErrorCode.badRequest:
        _show(const Scanning(unreadable: true));
        _returnIn(noteFor);
      case ApiErrorCode.employeeUnavailable || ApiErrorCode.scanNotAllowed:
        _show(const SeeHr());
        _returnIn(hrNoteFor);
      case ApiErrorCode.terminalOff:
        await _checkInNow();
        _show(const Scanning());
      default:
        _log.warning('A scan failed: ${e.kind.name} ${e.statusCode ?? ''}');
        _show(const NoConnection());
    }
  }

  /// "Change": stays until they choose; the time on the screen stops.
  void chooseProject() {
    final view = _view;
    if (view is! Registered) return;
    _back?.cancel();
    _show(ChoosingProject(view.result, view.qrCode));
  }

  Future<void> switchTo(ActivityKind kind, {int? projectId}) async {
    final view = _view;
    if (view is! ChoosingProject) return;
    _setBusy(true);
    try {
      await _api.switchTo(
        TerminalSwitchRequest(qrCode: view.qrCode, kind: kind, at: _clock().toUtc(), projectId: projectId),
      );
      _show(const Scanning());
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return await _disconnected();
      _show(ChoosingProject(view.result, view.qrCode, failed: true));
    } finally {
      _setBusy(false);
    }
  }

  /// Back to the camera, now.
  void backToCamera() {
    _back?.cancel();
    _show(const Scanning());
  }

  void _returnIn(Duration after) {
    _back?.cancel();
    _back = Timer(after, backToCamera);
  }

  void _setBusy(bool busy) {
    _busy = busy;
    _notify();
  }

  void _show(TerminalView view) {
    _view = view;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _back?.cancel();
    _checkIn?.cancel();
    super.dispose();
  }
}

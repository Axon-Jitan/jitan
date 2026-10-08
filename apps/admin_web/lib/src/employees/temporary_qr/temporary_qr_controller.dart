import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// State of a temporary QR modal: generating, shown with a live countdown,
/// expired, or failed. Each [generate] asks the server for a new QR, which
/// invalidates the previous one. The QR value is a credential: it lives
/// only here, is drawn as a QR and is dropped when the modal closes.
class TemporaryQrController extends ChangeNotifier {
  TemporaryQrController({
    required this._api,
    required this.companyId,
    required this.userId,
    required this.purpose,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    generate();
  }

  final EmployeesApi _api;
  final int companyId;
  final int userId;
  final TemporaryQrPurpose purpose;
  final DateTime Function() _clock;

  TemporaryQrResponse? _qr;

  /// `null` while generating or after a failure.
  TemporaryQrResponse? get qr => _qr;

  /// How long the QR was valid when it was generated (for "VALID FOR 10 MIN").
  Duration? _lifetime;
  Duration? get lifetime => _lifetime;

  ApiClientException? _failure;
  ApiClientException? get failure => _failure;

  bool _generating = false;
  bool get generating => _generating;

  Timer? _ticker;
  var _disposed = false;

  /// Time left; zero once expired.
  Duration get remaining {
    final qr = _qr;
    if (qr == null) return Duration.zero;
    final left = qr.expiresAt.difference(_clock().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isExpired => _qr != null && remaining == Duration.zero;

  Future<void> generate() async {
    if (_generating) return;
    _generating = true;
    _failure = null;
    _qr = null;
    _ticker?.cancel();
    notifyListeners();
    try {
      final qr = await _api.temporaryQr(companyId, userId, purpose);
      if (_disposed) return;
      _qr = qr;
      _lifetime = qr.expiresAt.difference(_clock().toUtc());
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } on ApiClientException catch (e) {
      if (_disposed) return;
      _failure = e;
    }
    _generating = false;
    notifyListeners();
  }

  void _tick() {
    if (isExpired) _ticker?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _qr = null;
    super.dispose();
  }
}

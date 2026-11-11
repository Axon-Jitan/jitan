import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// State of a temporary QR modal: generating, shown with a live countdown,
/// expired, failed, or [used]. Each [generate] asks the server for a new QR,
/// which invalidates the previous one. The QR value is a credential: it
/// lives only here, is drawn as a QR and is dropped when the modal closes.
///
/// While a QR shows, the employee is looked up every [watchEvery]: once
/// they have a password the QR did its job (onboarding complete ⇔
/// `userPassword IS NOT NULL`; recovery sets a new one), so the modal can
/// close. The QR itself is only used up when they finish, not at the scan.
class TemporaryQrController extends ChangeNotifier {
  TemporaryQrController({
    required this._api,
    required this.companyId,
    required this.userId,
    required this.purpose,
    DateTime Function()? clock,
    this.watchEvery = defaultWatchEvery,
  }) : _clock = clock ?? DateTime.now {
    generate();
  }

  /// How often the employee is looked up while a QR shows.
  static const defaultWatchEvery = Duration(seconds: 3);

  final EmployeesApi _api;
  final int companyId;
  final int userId;
  final TemporaryQrPurpose purpose;
  final DateTime Function() _clock;
  final Duration watchEvery;

  TemporaryQrResponse? _qr;

  /// `null` while generating or after a failure.
  TemporaryQrResponse? get qr => _qr;

  ApiClientException? _failure;
  ApiClientException? get failure => _failure;

  bool _generating = false;
  bool get generating => _generating;

  /// The employee finished with this QR: they have a password now.
  bool _used = false;
  bool get used => _used;

  Timer? _ticker;
  Timer? _watcher;
  bool _looking = false;
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
    _watcher?.cancel();
    notifyListeners();
    try {
      final qr = await _api.temporaryQr(companyId, userId, purpose);
      if (_disposed) return;
      _qr = qr;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _watcher = Timer.periodic(watchEvery, (_) => _look());
    } on ApiClientException catch (e) {
      if (_disposed) return;
      _failure = e;
    }
    _generating = false;
    notifyListeners();
  }

  void _tick() {
    if (isExpired) {
      _ticker?.cancel();
      _watcher?.cancel();
    }
    notifyListeners();
  }

  /// One look at the employee; a failed look changes nothing (the next one
  /// tries again).
  Future<void> _look() async {
    if (_looking || _used || _qr == null) return;
    _looking = true;
    try {
      final details = await _api.details(companyId, userId);
      if (_disposed || !details.isActivated) return;
      _used = true;
      _ticker?.cancel();
      _watcher?.cancel();
      notifyListeners();
    } on ApiClientException {
      // Offline for a moment: keep showing the QR.
    } finally {
      _looking = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _watcher?.cancel();
    _qr = null;
    super.dispose();
  }
}

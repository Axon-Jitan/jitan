import 'package:jitan_models/jitan_models.dart';

/// Which QR a store entry is for: one current QR per employee and purpose.
typedef TemporaryTokenKey = ({int userId, TemporaryQrPurpose purpose});

/// Where a token stands, from one device's point of view.
enum TemporaryTokenState {
  /// Not the current QR: replaced by a newer one, expired, or forgotten (the
  /// in-memory store after a restart).
  unknown,

  /// Current and unused.
  available,

  /// This device holds it: a completion is running or was interrupted.
  claimedByThisDevice,

  /// This device already completed with it.
  consumedByThisDevice,

  /// Held or used by another device (or used, when no device is given).
  usedElsewhere,
}

/// Temporary server-side state of temporary QRs (IT decision 2026-10-08):
/// never MySQL. Holds only what one-time use and revocation need, per
/// employee and purpose: the current token id, its expiry, which device
/// holds it, and whether it was used. Entries disappear at expiry.
///
/// Implementations must make [claim] atomic (check and set as one step):
/// the in-memory store does so within one isolate; a shared cache (e.g.
/// Redis, persistence off, key TTL = expiry) would use a script or a
/// compare-and-set. A shared store is needed only when the API runs as more
/// than one instance.
abstract interface class TemporaryTokenStore {
  /// Makes [tokenId] the only valid token for [key] until [expiresAt]. Any
  /// previous token for [key] stops being valid (regeneration revokes it).
  Future<void> replace(TemporaryTokenKey key, String tokenId, DateTime expiresAt);

  /// The state of [tokenId], without changing it.
  Future<TemporaryTokenState> inspect(TemporaryTokenKey key, String tokenId, {String? deviceId});

  /// If [tokenId] is [TemporaryTokenState.available], [deviceId] now holds it.
  /// Returns the state found **before** the call, so `available` means the
  /// claim succeeded.
  Future<TemporaryTokenState> claim(TemporaryTokenKey key, String tokenId, String deviceId);

  /// Gives a claimed token back (the completion was refused), so it can be
  /// used again. No effect if [deviceId] does not hold it.
  Future<void> release(TemporaryTokenKey key, String tokenId, String deviceId);

  /// Marks [tokenId] used. It stays known until it expires, so a reuse is
  /// reported as used rather than unknown.
  Future<void> consume(TemporaryTokenKey key, String tokenId, String deviceId);
}

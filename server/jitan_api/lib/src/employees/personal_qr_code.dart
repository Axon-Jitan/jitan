import 'dart:convert';
import 'dart:math';

/// A new value for `tblUser.userQRcode`: the employee's personal QR, scanned
/// at a Jitan Terminal (roadmap §21).
///
/// 18 random bytes from a cryptographically secure source, base64url-encoded
/// to 24 characters (144 bits): unguessable, so knowing one employee's QR
/// reveals nothing about another's. The required format and column length
/// are not defined by the ERD (CLARIFY-12).
String newPersonalQrCode([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(_byteCount, (_) => source.nextInt(256));
  return base64Url.encode(bytes);
}

const _byteCount = 18;

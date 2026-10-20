import 'dart:io';
import 'dart:typed_data';

import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/database_config.dart';
import 'package:jitan_api/src/database/database_tls.dart';
import 'package:test/test.dart';

DatabaseConfig _config({bool secure = true, String? caFile, String? fingerprint, Set<String>? fingerprints}) =>
    DatabaseConfig(
  host: 'db',
  port: 3306,
  name: 'jitan',
  user: 'jitan',
  password: 'secret',
  secure: secure,
  tlsCaFile: caFile,
  tlsFingerprints: fingerprints ?? {?fingerprint},
);

/// Only `der` is read by the pin check.
class _Certificate implements X509Certificate {
  _Certificate(List<int> bytes) : der = Uint8List.fromList(bytes);

  @override
  final Uint8List der;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final pinnedDer = [1, 2, 3, 4];
  final pinned = certificateFingerprint(pinnedDer);

  test('fingerprint pinning accepts only the pinned certificate', () {
    final tls = DatabaseTls.of(_config(fingerprint: pinned));
    expect(tls.context, isNotNull, reason: 'no trusted roots, so every certificate reaches the check');
    expect(tls.onBadCertificate!(_Certificate(pinnedDer)), isTrue);
    expect(tls.onBadCertificate!(_Certificate([9, 9, 9])), isFalse);
  });

  test('every certificate the TLS layer flags must be pinned: a pinned CA does not let another server certificate in',
      () {
    final caDer = [5, 6, 7];
    final tls = DatabaseTls.of(_config(fingerprints: {pinned, certificateFingerprint(caDer)}));
    expect(tls.onBadCertificate!(_Certificate(caDer)), isTrue);
    expect(tls.onBadCertificate!(_Certificate(pinnedDer)), isTrue);
    expect(tls.onBadCertificate!(_Certificate([9, 9, 9])), isFalse);
  });

  test('a CA file that cannot be read stops startup', () {
    expect(() => DatabaseTls.of(_config(caFile: 'missing-ca.pem')), throwsA(isA<ConfigException>()));
  });

  test('without verification (development), the driver accepts the certificate', () {
    final tls = DatabaseTls.of(_config());
    expect(tls.onBadCertificate!(_Certificate([9])), isTrue);
  });

  test('without TLS, nothing is passed', () {
    final tls = DatabaseTls.of(_config(secure: false));
    expect((tls.context, tls.onBadCertificate), (null, null));
  });

  test('fingerprints are normalized from openssl output', () {
    expect(normalizeFingerprint('70:26:23:E5:D0:AE:AA:B2:9B:51:AA:5B:C2:85:51:FF:FD:C3:8A:BD:E1:04:32:0F:4F:6B:D2:BE:08:E3:85:B9'),
        '702623e5d0aeaab29b51aa5bc28551fffdc38abde104320f4f6bd2be08e385b9');
    expect(normalizeFingerprint('not a fingerprint'), isNull);
    expect(certificateFingerprint(pinnedDer), hasLength(64));
  });
}

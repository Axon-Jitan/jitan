import 'package:crypto/crypto.dart';
import 'package:employee_mobile/src/config/certificate_pin.dart';
import 'package:employee_mobile/src/config/employee_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The API server's self-signed certificate (IT's `agapp05`): accepted only for
/// the API's address and port, and only with the pinned fingerprint.
void main() {
  final certificate = List<int>.generate(64, (i) => i);
  final colons = [
    for (final byte in sha256.convert(certificate).bytes) byte.toRadixString(16).padLeft(2, '0').toUpperCase(),
  ].join(':');
  final pin = CertificatePin(host: '10.1.101.65', port: 8080, sha256Fingerprint: colons);

  test('the pinned certificate from the API address is accepted, written with colons or not', () {
    expect(pin.accepts(certificate, '10.1.101.65', 8080), isTrue);
    expect(
      CertificatePin(host: '10.1.101.65', port: 8080, sha256Fingerprint: colons.replaceAll(':', '').toLowerCase()).accepts(certificate, '10.1.101.65', 8080),
      isTrue,
    );
  });

  test('another certificate, another address or another port is refused', () {
    expect(pin.accepts([...certificate, 0], '10.1.101.65', 8080), isFalse);
    expect(pin.accepts(certificate, '10.1.101.66', 8080), isFalse);
    expect(pin.accepts(certificate, '10.1.101.65', 443), isFalse);
  });

  test('the build sets the pin; without it the phone\'s usual checks apply', () {
    expect(EmployeeConfig.parse('https://10.1.101.65:8080', certificateSha256: colons)!.certificateSha256, colons);
    expect(EmployeeConfig.parse('https://10.1.101.65:8080')!.certificateSha256, isNull);
  });
}

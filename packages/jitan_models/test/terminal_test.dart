import 'dart:convert';

import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

Map<String, Object?> _wire(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  test('a terminal survives the wire', () {
    final terminal = Terminal(
      id: 1,
      name: 'Almeco Reception',
      type: const TerminalTypeChoice(id: 1, name: 'Office'),
      companyId: 2,
      companyName: 'Almeco',
      scanningEnabled: true,
      status: TerminalStatus.notConnected,
      addressId: 3,
      addressName: 'Almeco office',
      lastSeen: DateTime.utc(2026, 11, 1, 9),
    );

    final back = Terminal.fromJson(_wire(terminal.toJson()));

    expect(back.status, TerminalStatus.notConnected);
    expect(back.lastSeen, DateTime.utc(2026, 11, 1, 9));
    expect(back.type.name, 'Office');
    expect(back.toJson().keys, isNot(contains('secretHash')));
  });

  test('a request is trimmed; an empty plate is no plate', () {
    const request = TerminalRequest(name: ' Van ', typeId: 2, companyId: 1, plateNumber: '  ');

    expect(request.trimmed().name, 'Van');
    expect(request.trimmed().plateNumber, isNull);
  });

  test('a scan says its moment with an offset', () {
    expect(
      () => TerminalScanRequest.fromJson({'qrCode': 'x', 'at': '2026-11-01T09:00:00'}),
      throwsFormatException,
    );
    final scan = TerminalScanRequest.fromJson({'qrCode': 'x', 'at': '2026-11-01T10:00:00+01:00'});
    expect(scan.at, DateTime.utc(2026, 11, 1, 9));
  });

  test('credentials stay out of toString', () {
    const pair = TerminalPairRequest(qrCode: 'secret-qr', deviceId: 'd');
    final scan = TerminalScanRequest(qrCode: 'secret-qr', at: DateTime.utc(2026));

    expect('$pair$scan', isNot(contains('secret-qr')));
    const answer = TerminalPairResponse(
      token: 'secret-token',
      terminal: TerminalInfo(id: 1, name: 'A', companyName: 'B', canScan: true),
    );
    expect('$answer', isNot(contains('secret-token')));
  });

  test('a scan result survives the wire', () {
    const result = TerminalScanResult(
      outcome: TerminalScanOutcome.alreadyCheckedIn,
      timeLocal: '09:42',
      firstName: 'Disan',
      projects: [MyProject(id: 1, name: 'Towers', companyId: 2, companyName: 'Almeco', isClient: true, isCurrent: true)],
    );

    final back = TerminalScanResult.fromJson(_wire(result.toJson()));

    expect(back.outcome, TerminalScanOutcome.alreadyCheckedIn);
    expect(back.projects.single.name, 'Towers');
  });
}

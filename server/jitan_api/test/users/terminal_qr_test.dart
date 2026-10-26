import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

/// `GET /me/terminal-qr` (My QR, Figma 50:67): the signed-in employee's own
/// Terminal QR, never cached.
void main() {
  test('the signed-in employee gets their own Terminal QR, not cached', () async {
    final app = TestApp(devUserId: 1, activeUserIds: {1, 2});
    app.users.terminalQrs
      ..[1] = 'terminal-qr-one'
      ..[2] = 'terminal-qr-two';

    final response = await app.get('/me/terminal-qr');

    expect(response.statusCode, 200);
    expect(response.headers['cache-control'], 'no-store');
    expect(TerminalQr.fromJson(await jsonBody(response)).qrCode, 'terminal-qr-one', reason: 'only their own');
  });

  test('404 when the account has none; 401 without an identity', () async {
    final app = TestApp(devUserId: 1, activeUserIds: {1});
    expect((await app.get('/me/terminal-qr')).statusCode, 404);
    expect((await TestApp(devUserId: null).get('/me/terminal-qr')).statusCode, 401);
  });
}

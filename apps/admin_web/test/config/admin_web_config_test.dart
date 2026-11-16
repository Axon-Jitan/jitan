import 'package:admin_web/src/config/admin_web_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only a Mapbox public token may be in the website (review L7)', () {
    expect(AdminWebConfig.isPublicMapboxToken('pk.eyJ1IjoiamF0YW4ifQ.abc'), isTrue);
    for (final other in ['sk.eyJ1IjoiamF0YW4ifQ.abc', 'tk.abc', '', 'pk']) {
      expect(AdminWebConfig.isPublicMapboxToken(other), isFalse, reason: other);
    }
  });
}

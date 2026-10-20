import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

void main() {
  test('the web theme has no click effect; the mobile theme keeps the touch ripple', () {
    final web = JitanTheme.web();
    expect(web.splashFactory, NoSplash.splashFactory);
    expect(web.highlightColor, Colors.transparent);
    expect(web.filledButtonTheme.style?.overlayColor?.resolve({WidgetState.pressed}), Colors.transparent);
    expect(web.filledButtonTheme.style?.overlayColor?.resolve({WidgetState.hovered}), isNull, reason: 'hover stays');

    expect(JitanTheme.light().splashFactory, isNot(NoSplash.splashFactory));
  });
}

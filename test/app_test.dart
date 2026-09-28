import 'package:dont_trust_the_game/main.dart';
import 'package:dont_trust_the_game/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('menu → boot → gameplay', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.load();
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(DontTrustTheGame(settings: settings));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('TRUST\nTHE GAME'), findsOneWidget);
    expect(find.text("don't"), findsOneWidget);

    await tester.tap(find.text('[ START ]'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('DTTG // BOOT 0.9.3'), findsOneWidget);

    await tester.tap(find.text('TAP TO SKIP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('01 / TRUST'), findsOneWidget);
    expect(find.text('[ II ]'), findsOneWidget);

    await tester.tap(find.text('[ II ]'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('[ RESUME ]'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.load();
    await tester.pumpWidget(DontTrustTheGame(settings: settings));
    await tester.tap(find.text('[ SETTINGS ]'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LET THE GAME HELP YOU'), findsOneWidget);
    await tester.tap(find.text('FAST'));
    await tester.pump();
    expect(settings.speed, TextSpeed.fast);
  });
}

import 'package:dont_trust_the_game/audio/cues.dart';
import 'package:dont_trust_the_game/audio/game_audio.dart';
import 'package:dont_trust_the_game/main.dart';
import 'package:dont_trust_the_game/screens/game_screen.dart';
import 'package:dont_trust_the_game/settings.dart';
import 'package:dont_trust_the_game/widgets/common.dart';
import 'package:dont_trust_the_game/widgets/analog_stick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/recording_audio.dart';

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

    expect(find.text('REDUCE GLITCH'), findsOneWidget);
    await tester.tap(find.text('[ OFF ]').last); // last toggle row
    await tester.pump();
    expect(settings.reduceGlitch, isTrue);
  });
  testWidgets('buttons click', (tester) async {
    final a = RecordingAudio();
    var taps = 0;
    await tester.pumpWidget(
      AudioScope(
        audio: a,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BlockButton('[ GO ]', onTap: () => taps++),
                HudButton('[ II ]', onTap: () => taps++),
                const BlockButton('[ OFF ]', onTap: null),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('[ GO ]'));
    await tester.tap(find.text('[ II ]'));
    await tester.tap(find.text('[ OFF ]'));
    expect(taps, 2);
    expect(a.played, [Sfx.click, Sfx.click]);
  });

  testWidgets('analog stick sends a direction and clears it on release', (
    tester,
  ) async {
    final values = <Offset>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: AnalogStick(onChanged: values.add)),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AnalogStick)),
    );
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    expect(values.last.dx, greaterThan(0));
    await gesture.up();
    await tester.pump();
    expect(values.last, Offset.zero);
  });

  testWidgets('menu lullaby, quiet boot with ticks, game, back to menu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.load();
    final a = RecordingAudio();
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(DontTrustTheGame(settings: settings, audio: a));
    await tester.pump(const Duration(milliseconds: 100));
    expect(a.moods, [Mood.trust]);

    await tester.tap(find.text('[ START ]'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(a.moods.last, Mood.silence);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(a.count(Sfx.bootTick), 4);
    expect(a.count(Sfx.bootOk), 4);
    expect(a.played, contains(Sfx.hello));

    await tester.tap(find.text('TAP TO SKIP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(a.moods.last, Mood.trust);

    await tester.tap(find.text('[ II ]'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('[ MAIN MENU ]'));
    await tester.pump();
    // The menu has its music as soon as leaving starts, while the game is
    // still fading out.
    expect(find.byType(GameScreen), findsOneWidget);
    final left = a.calls.sublist(a.calls.lastIndexOf('duck true'));
    expect(left, containsAllInOrder(['mood trust', 'uncover', 'duck false']));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsNothing);
    expect(
      a.calls.sublist(a.calls.lastIndexOf('duck true')),
      left,
      reason: 'said once',
    );
  });

  testWidgets('backing out of the boot screen brings the lullaby back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.load();
    final a = RecordingAudio();
    await tester.pumpWidget(DontTrustTheGame(settings: settings, audio: a));
    await tester.tap(find.text('[ START ]'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(a.moods.last, Mood.silence);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(a.moods.last, Mood.trust);
  });

  testWidgets('tapping the first volume cell at 1 mutes', (tester) async {
    SharedPreferences.setMockInitialValues({'music': 1});
    final settings = await SettingsStore.load();
    final a = RecordingAudio();
    await tester.pumpWidget(DontTrustTheGame(settings: settings, audio: a));
    await tester.tap(find.text('[ SETTINGS ]'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    a.clear();
    await tester.tap(find.byKey(const ValueKey('music-0')));
    await tester.pump();
    expect(settings.music, 0);
    await tester.tap(find.byKey(const ValueKey('music-0')));
    await tester.pump();
    expect(settings.music, 1);
    await tester.tap(find.byKey(const ValueKey('music-4')));
    await tester.pump();
    expect(settings.music, 5);
    expect(a.count(Sfx.click), 3);
  });
}

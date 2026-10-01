import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/audio_director.dart';
import 'audio/game_audio.dart';
import 'audio/soloud_backend.dart';
import 'screens/main_menu.dart';
import 'settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: C.void_,
    ),
  );
  final settings = await SettingsStore.load();
  final audio = AudioDirector(SoloudBackend(), settings);
  unawaited(
    audio.start(),
  ); // loads in the background; the game never waits on sound
  // Let the audio device rest while the app is in the background.
  AppLifecycleListener(onHide: audio.suspend, onShow: audio.resume);
  runApp(DontTrustTheGame(settings: settings, audio: audio));
}

/// Makes the [SettingsStore] available to every screen.
class AppScope extends InheritedNotifier<SettingsStore> {
  const AppScope({
    super.key,
    required SettingsStore settings,
    required super.child,
  }) : super(notifier: settings);

  static SettingsStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class DontTrustTheGame extends StatelessWidget {
  const DontTrustTheGame({
    super.key,
    required this.settings,
    this.audio = const SilentAudio(),
  });
  final SettingsStore settings;
  final GameAudio audio;

  @override
  Widget build(BuildContext context) {
    return AudioScope(
      audio: audio,
      child: AppScope(
        settings: settings,
        child: MaterialApp(
          title: "Don't Trust The Game",
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: C.void_,
            fontFamily: kMono,
            splashFactory: NoSplash.splashFactory,
          ),
          home: const MainMenuScreen(),
        ),
      ),
    );
  }
}

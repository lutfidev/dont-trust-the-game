import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/main_menu.dart';
import 'settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: C.void_,
  ));
  final settings = await SettingsStore.load();
  runApp(DontTrustTheGame(settings: settings));
}

/// Makes the [SettingsStore] available to every screen.
class AppScope extends InheritedNotifier<SettingsStore> {
  const AppScope({super.key, required SettingsStore settings, required super.child})
      : super(notifier: settings);

  static SettingsStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class DontTrustTheGame extends StatelessWidget {
  const DontTrustTheGame({super.key, required this.settings});
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return AppScope(
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
    );
  }
}

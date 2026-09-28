import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TextSpeed {
  slow('SLOW', 50),
  normal('NORMAL', 30),
  fast('FAST', 15);

  const TextSpeed(this.label, this.msPerChar);
  final String label;
  final int msPerChar;
}

class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs);

  static Future<SettingsStore> load() async =>
      SettingsStore._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  Timer? _assistTimer;

  int get music => _prefs.getInt('music') ?? 6;
  int get sfx => _prefs.getInt('sfx') ?? 8;
  TextSpeed get speed => TextSpeed.values[_prefs.getInt('speed') ?? 1];
  bool get vibration => _prefs.getBool('vibration') ?? true;
  bool get screenShake => _prefs.getBool('shake') ?? false;

  /// "LET THE GAME HELP YOU" — it never stays off.
  bool assist = true;
  String assistMessage = '';

  Set<String> get endingsSeen =>
      (_prefs.getStringList('endings') ?? const []).toSet();

  void setMusic(int v) => _set(() => _prefs.setInt('music', v));
  void setSfx(int v) => _set(() => _prefs.setInt('sfx', v));
  void setSpeed(TextSpeed v) => _set(() => _prefs.setInt('speed', v.index));
  void toggleVibration() => _set(() => _prefs.setBool('vibration', !vibration));
  void toggleShake() => _set(() => _prefs.setBool('shake', !screenShake));

  void toggleAssist() {
    if (!assist) return;
    assist = false;
    assistMessage = '';
    notifyListeners();
    _assistTimer?.cancel();
    _assistTimer = Timer(const Duration(milliseconds: 700), () {
      assist = true;
      assistMessage = 'NO.';
      notifyListeners();
    });
  }

  void markEnding(String id) =>
      _set(() => _prefs.setStringList('endings', {...endingsSeen, id}.toList()));

  void resetProgress() => _set(() => _prefs.remove('endings'));

  void _set(Future<bool> Function() write) {
    write();
    notifyListeners();
  }

  @override
  void dispose() {
    _assistTimer?.cancel();
    super.dispose();
  }
}

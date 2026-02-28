import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  SharedPreferences? _prefs;

  factory SettingsService() => _instance;

  SettingsService._internal();

  Future<SharedPreferences> get _getPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await _getPrefs;
    return {
      'dailyLimit': prefs.getInt('dailyLimit') ?? 3,
      'defaultFilter': prefs.getString('defaultFilter') ?? 'Normal',
      'imageQuality': prefs.getString('imageQuality') ?? 'High',
      'remindersEnabled': prefs.getBool('remindersEnabled') ?? false,
      'reminderTime': prefs.getString('reminderTime') ?? '20:00',
      'useSystemCamera': prefs.getBool('useSystemCamera') ?? false,
      'mirrorFrontCamera': prefs.getBool('mirrorFrontCamera') ?? true,
      'hapticFeedback': prefs.getBool('hapticFeedback') ?? true,
      'shutterSound': prefs.getBool('shutterSound') ?? true,
    };
  }

  Future<void> setDailyLimit(int limit) async {
    final prefs = await _getPrefs;
    await prefs.setInt('dailyLimit', limit);
  }

  Future<void> setImageQuality(String quality) async {
    final prefs = await _getPrefs;
    await prefs.setString('imageQuality', quality);
  }

  Future<void> setDefaultFilter(String filter) async {
    final prefs = await _getPrefs;
    await prefs.setString('defaultFilter', filter);
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('remindersEnabled', enabled);
  }

  Future<void> setReminderTime(String time) async {
    final prefs = await _getPrefs;
    await prefs.setString('reminderTime', time);
  }

  Future<void> setUseSystemCamera(bool useSystem) async {
    final prefs = await _getPrefs;
    await prefs.setBool('useSystemCamera', useSystem);
  }

  Future<void> setMirrorFrontCamera(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('mirrorFrontCamera', enabled);
  }

  Future<void> setHapticFeedback(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('hapticFeedback', enabled);
  }

  Future<void> setShutterSound(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('shutterSound', enabled);
  }

  Future<bool> clearAppCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
      return true;
    } catch (e) {
      debugPrint('Cache clearing failed: $e');
      return false;
    }
  }

  Future<void> resetAllSettings() async {
    final prefs = await _getPrefs;
    await prefs.clear();
  }
}

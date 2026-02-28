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
      'biometricLock': prefs.getBool('biometricLock') ?? false,
      'showWidgetOnHome': prefs.getBool('showWidgetOnHome') ?? true,
      'shareCount': prefs.getInt('shareCount') ?? 0,
      'editCount': prefs.getInt('editCount') ?? 0,
      'settingsChangeCount': prefs.getInt('settingsChangeCount') ?? 0,
      'flashUsageCount': prefs.getInt('flashUsageCount') ?? 0,
      'cacheClearCount': prefs.getInt('cacheClearCount') ?? 0,
    };
  }

  Future<void> setDailyLimit(int limit) async {
    final prefs = await _getPrefs;
    await prefs.setInt('dailyLimit', limit);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setImageQuality(String quality) async {
    final prefs = await _getPrefs;
    await prefs.setString('imageQuality', quality);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setDefaultFilter(String filter) async {
    final prefs = await _getPrefs;
    await prefs.setString('defaultFilter', filter);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('remindersEnabled', enabled);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setReminderTime(String time) async {
    final prefs = await _getPrefs;
    await prefs.setString('reminderTime', time);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setUseSystemCamera(bool useSystem) async {
    final prefs = await _getPrefs;
    await prefs.setBool('useSystemCamera', useSystem);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setMirrorFrontCamera(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('mirrorFrontCamera', enabled);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setHapticFeedback(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('hapticFeedback', enabled);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setShutterSound(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('shutterSound', enabled);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setBiometricLock(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('biometricLock', enabled);
    await trackEvent('settingsChangeCount');
  }

  Future<void> setShowWidgetOnHome(bool enabled) async {
    final prefs = await _getPrefs;
    await prefs.setBool('showWidgetOnHome', enabled);
    await trackEvent('settingsChangeCount');
  }

  Future<void> trackEvent(String key) async {
    final prefs = await _getPrefs;
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
  }


  Future<bool> clearAppCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
      await trackEvent('cacheClearCount');
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

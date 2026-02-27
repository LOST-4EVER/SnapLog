import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  late SharedPreferences _prefs;
  bool _initialized = false;

  factory SettingsService() => _instance;

  SettingsService._internal();

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  Future<Map<String, dynamic>> getSettings() async {
    await _ensureInitialized();
    return {
      'dailyLimit': _prefs.getInt('dailyLimit') ?? 3,
      'enableFlash': _prefs.getBool('enableFlash') ?? false,
      'defaultFilter': _prefs.getString('defaultFilter') ?? 'Normal',
      'imageQuality': _prefs.getString('imageQuality') ?? 'High',
    };
  }

  Future<void> setDailyLimit(int limit) async {
    await _ensureInitialized();
    await _prefs.setInt('dailyLimit', limit);
  }

  Future<void> setImageQuality(String quality) async {
    await _ensureInitialized();
    await _prefs.setString('imageQuality', quality);
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
    } catch (e) {
      // Cache clearing failed
    }
  }

  Future<void> resetSettings() async {
    await _ensureInitialized();
    await _prefs.clear();
  }
}

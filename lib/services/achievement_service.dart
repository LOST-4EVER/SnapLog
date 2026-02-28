import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final double progress; 
  final String stat; 

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
    this.progress = 0.0,
    this.stat = "",
  });
}

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final List<Map<String, dynamic>> _achievementDefinitions = [
    {'id': 'first_snap', 'title': 'Early Bird', 'desc': 'Take your first photo', 'icon': '📸'},
    {'id': 'streak_7', 'title': 'Week Warrior', 'desc': 'Maintain a 7-day streak', 'icon': '🔥'},
    {'id': 'streak_30', 'title': 'Monthly Master', 'desc': 'Maintain a 30-day streak', 'icon': '🏆'},
    {'id': 'streak_100', 'title': 'Century Club', 'desc': 'Maintain a 100-day streak', 'icon': '💯'},
    {'id': 'count_50', 'title': 'Collector', 'desc': 'Save 50 memories', 'icon': '📚'},
    {'id': 'count_250', 'title': 'Archivist', 'desc': 'Save 250 memories', 'icon': '🏛️'},
    {'id': 'all_moods', 'title': 'Emotional Explorer', 'desc': 'Use every mood emoji at least once', 'icon': '🌈'},
    {'id': 'night_owl', 'title': 'Night Owl', 'desc': 'Take a photo between 10 PM and 4 AM', 'icon': '🦉'},
    {'id': 'early_riser', 'title': 'Sun Seeker', 'desc': 'Take a photo between 5 AM and 8 AM', 'icon': '🌅'},
    {'id': 'filter_fan', 'title': 'Stylist', 'desc': 'Use filters 10 times', 'icon': '🎨'},
    {'id': 'bw_soul', 'title': 'Noir Master', 'desc': 'Use B&W filter 20 times', 'icon': '🎞️'},
    {'id': 'sepia_soul', 'title': 'Vintage Vibes', 'desc': 'Use Sepia filter 20 times', 'icon': '⏳'},
    {'id': 'location_legend', 'title': 'Voyager', 'desc': 'Photos in 5 different locations', 'icon': '📍'},
    {'id': 'talkative', 'title': 'Storyteller', 'desc': '10 captions with over 50 characters', 'icon': '✍️'},
    {'id': 'weekend', 'title': 'Weekend Wanderer', 'desc': 'Snap on both Sat and Sun', 'icon': '🎡'},
    {'id': 'variety', 'title': 'Mood Swinger', 'desc': 'Use 5 different moods in one week', 'icon': '🎭'},
    {'id': 'flash_master', 'title': 'Illuminator', 'desc': 'Use Flash/Torch mode 10 times', 'icon': '🔦'},
    {'id': 'planter_ai', 'title': 'Planter Hunter', 'desc': 'AI: Detect 3 planters in your photos', 'icon': '🌿'},
    {'id': 'consistent', 'title': 'Regular', 'desc': 'Snaps at same hour for 3 days', 'icon': '⏰'},
    {'id': 'settings_guru', 'title': 'Tinkerer', 'desc': 'Change app settings 5 times', 'icon': '⚙️'},
    {'id': 'cleaner', 'title': 'Spring Cleaner', 'desc': 'Clear app cache once', 'icon': '🧹'},
    {'id': 'sharer', 'title': 'Socialite', 'desc': 'Share 10 memories', 'icon': '📤'},
    {'id': 'editor', 'title': 'Perfectionist', 'desc': 'Edit captions 5 times', 'icon': '✏️'},
    {'id': 'mood_stable', 'title': 'Steady Heart', 'desc': 'Use same mood for 5 days', 'icon': '❤️'},
    {'id': 'pro_user', 'title': 'SnapLog Pro', 'desc': 'Unlock 24 other achievements', 'icon': '💎'},
  ];

  Future<List<Achievement>> getAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final db = DatabaseHelper();
    final streak = await db.calculateStreak();
    final entries = await db.getEntries();
    
    List<Achievement> result = [];

    for (var def in _achievementDefinitions) {
      bool unlocked = false;
      double progress = 0.0;
      String stat = "";

      switch (def['id']) {
        case 'first_snap':
          unlocked = entries.isNotEmpty;
          progress = unlocked ? 1.0 : 0.0;
          break;
        case 'streak_7':
          progress = (streak / 7).clamp(0.0, 1.0);
          unlocked = streak >= 7;
          stat = "$streak/7 days";
          break;
        case 'streak_30':
          progress = (streak / 30).clamp(0.0, 1.0);
          unlocked = streak >= 30;
          stat = "$streak/30 days";
          break;
        case 'streak_100':
          progress = (streak / 100).clamp(0.0, 1.0);
          unlocked = streak >= 100;
          stat = "$streak/100 days";
          break;
        case 'count_50':
          progress = (entries.length / 50).clamp(0.0, 1.0);
          unlocked = entries.length >= 50;
          stat = "${entries.length}/50";
          break;
        case 'count_250':
          progress = (entries.length / 250).clamp(0.0, 1.0);
          unlocked = entries.length >= 250;
          stat = "${entries.length}/250";
          break;
        case 'all_moods':
          final usedMoods = entries.map((e) => e.mood).toSet();
          progress = (usedMoods.length / 12).clamp(0.0, 1.0);
          unlocked = usedMoods.length >= 12;
          stat = "${usedMoods.length}/12 moods";
          break;
        case 'night_owl':
          unlocked = entries.any((e) => e.timestamp.hour >= 22 || e.timestamp.hour <= 4);
          progress = unlocked ? 1.0 : 0.0;
          break;
        case 'early_riser':
          unlocked = entries.any((e) => e.timestamp.hour >= 5 && e.timestamp.hour <= 8);
          progress = unlocked ? 1.0 : 0.0;
          break;
        case 'filter_fan':
          final filtered = entries.where((e) => e.filter != 'Normal').length;
          progress = (filtered / 10).clamp(0.0, 1.0);
          unlocked = filtered >= 10;
          stat = "$filtered/10";
          break;
        case 'bw_soul':
          final bw = entries.where((e) => e.filter == 'B&W').length;
          progress = (bw / 20).clamp(0.0, 1.0);
          unlocked = bw >= 20;
          stat = "$bw/20";
          break;
        case 'sepia_soul':
          final sepia = entries.where((e) => e.filter == 'Sepia').length;
          progress = (sepia / 20).clamp(0.0, 1.0);
          unlocked = sepia >= 20;
          stat = "$sepia/20";
          break;
        case 'location_legend':
          final locs = entries.map((e) => e.location).whereType<String>().toSet().length;
          progress = (locs / 5).clamp(0.0, 1.0);
          unlocked = locs >= 5;
          stat = "$locs/5 sites";
          break;
        case 'talkative':
          final longCaps = entries.where((e) => e.caption.length > 50).length;
          progress = (longCaps / 10).clamp(0.0, 1.0);
          unlocked = longCaps >= 10;
          stat = "$longCaps/10";
          break;
        case 'weekend':
          final hasSat = entries.any((e) => e.timestamp.weekday == DateTime.saturday);
          final hasSun = entries.any((e) => e.timestamp.weekday == DateTime.sunday);
          unlocked = hasSat && hasSun;
          progress = (hasSat ? 0.5 : 0.0) + (hasSun ? 0.5 : 0.0);
          break;
        case 'planter_ai':
          final planters = entries.where((e) => e.tags?.contains('planter') ?? false).length;
          progress = (planters / 3).clamp(0.0, 1.0);
          unlocked = planters >= 3;
          stat = "$planters/3 plants";
          break;
        case 'settings_guru':
          final count = prefs.getInt('settingsChangeCount') ?? 0;
          progress = (count / 5).clamp(0.0, 1.0);
          unlocked = count >= 5;
          stat = "$count/5";
          break;
        case 'cleaner':
          final count = prefs.getInt('cacheClearCount') ?? 0;
          progress = count > 0 ? 1.0 : 0.0;
          unlocked = count > 0;
          break;
        case 'sharer':
          final count = prefs.getInt('shareCount') ?? 0;
          progress = (count / 10).clamp(0.0, 1.0);
          unlocked = count >= 10;
          stat = "$count/10";
          break;
        case 'editor':
          final count = prefs.getInt('editCount') ?? 0;
          progress = (count / 5).clamp(0.0, 1.0);
          unlocked = count >= 5;
          stat = "$count/5";
          break;
        case 'flash_master':
          final count = prefs.getInt('flashUsageCount') ?? 0;
          progress = (count / 10).clamp(0.0, 1.0);
          unlocked = count >= 10;
          stat = "$count/10";
          break;
        default:
          unlocked = false;
      }

      result.add(Achievement(
        id: def['id'],
        title: def['title'],
        description: def['desc'],
        icon: def['icon'],
        isUnlocked: unlocked,
        progress: progress,
        stat: stat,
      ));
    }
    
    int totalUnlocked = result.where((a) => a.isUnlocked && a.id != 'pro_user').length;
    int proIndex = result.indexWhere((a) => a.id == 'pro_user');
    if (proIndex != -1) {
      bool unlocked = totalUnlocked >= 24;
      result[proIndex] = Achievement(
        id: 'pro_user',
        title: result[proIndex].title,
        description: result[proIndex].description,
        icon: result[proIndex].icon,
        isUnlocked: unlocked,
        progress: (totalUnlocked / 24).clamp(0.0, 1.0),
        stat: "$totalUnlocked/24",
      );
    }

    return result;
  }

  Future<void> checkNewUnlocks(void Function(Achievement) onUnlocked) async {
    final prefs = await SharedPreferences.getInstance();
    final achievements = await getAchievements();
    
    for (var a in achievements) {
      if (a.isUnlocked) {
        final key = 'unlocked_notified_${a.id}';
        if (!(prefs.getBool(key) ?? false)) {
          await prefs.setBool(key, true);
          onUnlocked(a);
        }
      }
    }
  }
  
  Future<void> initNotificationState() async {
    final prefs = await SharedPreferences.getInstance();
    final isInitialized = prefs.getBool('achievements_notified_init') ?? false;
    if (!isInitialized) {
      final achievements = await getAchievements();
      for (var a in achievements) {
        if (a.isUnlocked) {
          await prefs.setBool('unlocked_notified_${a.id}', true);
        }
      }
      await prefs.setBool('achievements_notified_init', true);
    }
  }
}

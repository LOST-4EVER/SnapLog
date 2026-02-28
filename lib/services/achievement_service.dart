import 'database_helper.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
  });
}

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final List<Achievement> _achievements = [
    Achievement(id: 'first_snap', title: 'Early Bird', description: 'Take your first photo', icon: '📸'),
    Achievement(id: 'streak_7', title: 'Week Warrior', description: 'Maintain a 7-day streak', icon: '🔥'),
    Achievement(id: 'streak_30', title: 'Monthly Master', description: 'Maintain a 30-day streak', icon: '🏆'),
    Achievement(id: 'count_50', title: 'Collector', description: 'Save 50 memories', icon: '📚'),
    Achievement(id: 'all_moods', title: 'Emotional Explorer', description: 'Use every mood emoji at least once', icon: '🌈'),
  ];

  Future<List<Achievement>> getAchievements() async {
    final db = DatabaseHelper();
    final streak = await db.calculateStreak();
    final entries = await db.getEntries();
    
    return _achievements.map((a) {
      bool unlocked = false;
      switch (a.id) {
        case 'first_snap':
          unlocked = entries.isNotEmpty;
          break;
        case 'streak_7':
          unlocked = streak >= 7;
          break;
        case 'streak_30':
          unlocked = streak >= 30;
          break;
        case 'count_50':
          unlocked = entries.length >= 50;
          break;
        case 'all_moods':
          final usedMoods = entries.map((e) => e.mood).toSet();
          unlocked = usedMoods.length >= 12; // Assuming 12 moods available
          break;
      }
      return Achievement(
        id: a.id,
        title: a.title,
        description: a.description,
        icon: a.icon,
        isUnlocked: unlocked,
      );
    }).toList();
  }
}

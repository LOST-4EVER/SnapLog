import 'database_helper.dart';

class MoodData {
  final String date;
  final double score;
  final String mood;

  MoodData(this.date, this.score, this.mood);
}

class InsightsService {
  static final InsightsService _instance = InsightsService._internal();
  factory InsightsService() => _instance;
  InsightsService._internal();

  final Map<String, double> _moodScores = {
    "😊": 5.0,
    "🌟": 5.0,
    "🎉": 5.0,
    "🌈": 5.0,
    "📸": 4.0,
    "☕": 4.0,
    "🎨": 4.0,
    "🧗": 4.0,
    "🍕": 3.0,
    "💪": 3.0,
    "💼": 3.0,
    "😴": 2.0,
  };

  Future<List<MoodData>> getMoodTrends() async {
    final entries = await DatabaseHelper().getEntries();
    // Sort by date ascending
    final sortedEntries = entries.reversed.toList();
    
    // Take last 10 entries
    final recentEntries = sortedEntries.length > 10 
        ? sortedEntries.sublist(sortedEntries.length - 10) 
        : sortedEntries;

    return recentEntries.map((e) {
      final score = _moodScores[e.mood] ?? 3.0;
      final label = "${e.timestamp.month}/${e.timestamp.day}";
      return MoodData(label, score, e.mood);
    }).toList();
  }

  Future<Map<String, int>> getMoodDistribution() async {
    final entries = await DatabaseHelper().getEntries();
    final Map<String, int> distribution = {};
    
    for (var entry in entries) {
      distribution[entry.mood] = (distribution[entry.mood] ?? 0) + 1;
    }
    
    return distribution;
  }
}

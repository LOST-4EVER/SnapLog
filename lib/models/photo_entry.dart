import 'dart:convert';

class PhotoEntry {
  final int? id;
  final List<String> imagePaths;
  final String caption;
  final String mood;
  final String filter;
  final DateTime timestamp;
  final String? location;
  final String? tags;

  PhotoEntry({
    this.id,
    required this.imagePaths,
    required this.caption,
    required this.mood,
    required this.filter,
    required this.timestamp,
    this.location,
    this.tags,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePaths': jsonEncode(imagePaths), // Store as JSON string for safety
      'caption': caption,
      'mood': mood,
      'filter': filter,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
      'tags': tags,
    };
  }

  factory PhotoEntry.fromMap(Map<String, dynamic> map) {
    List<String> paths = [];
    try {
      final decoded = jsonDecode(map['imagePaths'] as String);
      if (decoded is List) {
        paths = decoded.map((e) => e.toString()).toList();
      }
    } catch (e) {
      // Fallback for old comma-separated format
      paths = (map['imagePaths'] as String).split(',');
    }

    return PhotoEntry(
      id: map['id'],
      imagePaths: paths,
      caption: map['caption'] ?? '',
      mood: map['mood'] ?? '😊',
      filter: map['filter'] ?? 'Normal',
      timestamp: DateTime.parse(map['timestamp']),
      location: map['location'],
      tags: map['tags'],
    );
  }
}

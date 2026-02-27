class PhotoEntry {
  final int? id;
  final String imagePath;
  final String caption;
  final String mood;
  final String filter;
  final DateTime timestamp;

  PhotoEntry({
    this.id,
    required this.imagePath,
    required this.caption,
    required this.mood,
    required this.filter,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'caption': caption,
      'mood': mood,
      'filter': filter,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PhotoEntry.fromMap(Map<String, dynamic> map) {
    return PhotoEntry(
      id: map['id'],
      imagePath: map['imagePath'],
      caption: map['caption'],
      mood: map['mood'],
      filter: map['filter'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

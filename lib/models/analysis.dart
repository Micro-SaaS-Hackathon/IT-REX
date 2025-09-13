class Analysis {
  final int? id;
  final String title;
  final DateTime timestamp;

  Analysis({
    this.id,
    required this.title,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Analysis.fromMap(Map<String, dynamic> map) {
    return Analysis(
      id: map['id'],
      title: map['title'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
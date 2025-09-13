class ChatMessage {
  final int? id;
  final String content;
  final bool isAI;
  final String? imageBase64;
  final int? analysisId;
  final DateTime timestamp;

  ChatMessage({
    this.id,
    required this.content,
    required this.isAI,
    this.imageBase64,
    this.analysisId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'isAI': isAI ? 1 : 0,
      'imageBase64': imageBase64,
      'analysisId': analysisId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      content: map['content'],
      isAI: map['isAI'] == 1,
      imageBase64: map['imageBase64'],
      analysisId: map['analysisId'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
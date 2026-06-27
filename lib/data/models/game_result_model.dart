class ResultEntry {
  final String name;
  final int score;
  ResultEntry({required this.name, required this.score});

  Map<String, dynamic> toMap() => {'name': name, 'score': score};

  factory ResultEntry.fromMap(Map<String, dynamic> m) =>
      ResultEntry(name: m['name'] ?? '', score: m['score'] ?? 0);
}

class GameResultModel {
  final String id;
  final String hostId;
  final String quizId;
  final String quizTitle;
  final DateTime playedAt;
  final int playerCount;
  final List<ResultEntry> entries; // sorted high -> low

  GameResultModel({
    required this.id,
    required this.hostId,
    required this.quizId,
    required this.quizTitle,
    required this.playedAt,
    required this.playerCount,
    required this.entries,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'hostId': hostId,
    'quizId': quizId,
    'quizTitle': quizTitle,
    'playedAt': playedAt.toIso8601String(),
    'playerCount': playerCount,
    'entries': entries.map((e) => e.toMap()).toList(),
  };

  factory GameResultModel.fromMap(Map<String, dynamic> map) => GameResultModel(
    id: map['id'] ?? '',
    hostId: map['hostId'] ?? '',
    quizId: map['quizId'] ?? '',
    quizTitle: map['quizTitle'] ?? 'Quiz',
    playedAt:
    DateTime.tryParse(map['playedAt'] ?? '') ?? DateTime.now(),
    playerCount: map['playerCount'] ?? 0,
    entries: (map['entries'] as List? ?? [])
        .map((e) => ResultEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

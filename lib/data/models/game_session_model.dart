enum GameStatus {
  lobby,
  countdown,
  question,
  leaderboard,
  ended,
}

class GameSessionModel {
  final String gamePin;
  final String hostId;
  final String quizId;
  final GameStatus status;
  final int currentQuestion;
  final Map<String, PlayerSession> players;
  final DateTime createdAt;
  final DateTime? countdownEndsAt;
  final int? questionStartAtMs;
  final int? questionDurationSeconds;

  GameSessionModel({
    required this.gamePin,
    required this.hostId,
    required this.quizId,
    required this.status,
    required this.currentQuestion,
    required this.players,
    required this.createdAt,
    this.countdownEndsAt,
    this.questionStartAtMs,
    this.questionDurationSeconds,
  });

  Map<String, dynamic> toMap() => {
    'gamePin': gamePin,
    'hostId': hostId,
    'quizId': quizId,
    'status': status.name,
    'currentQuestion': currentQuestion,
    'players': players.map((k, v) => MapEntry(k, v.toMap())),
    'createdAt': createdAt.toIso8601String(),
    'countdownEndsAt': countdownEndsAt?.toIso8601String(),
    'questionStartAtMs': questionStartAtMs,
    'questionDurationSeconds': questionDurationSeconds,
  };

  factory GameSessionModel.fromMap(Map<String, dynamic> map) =>
      GameSessionModel(
        gamePin: map['gamePin'],
        hostId: map['hostId'],
        quizId: map['quizId'],
        status: GameStatus.values.byName(map['status']),
        currentQuestion: map['currentQuestion'] ?? 0,
        players: (map['players'] as Map<dynamic, dynamic>? ?? {}).map(
              (k, v) => MapEntry(k.toString(),
              PlayerSession.fromMap(Map<String, dynamic>.from(v))),
        ),
        createdAt: DateTime.parse(map['createdAt']),
        countdownEndsAt: map['countdownEndsAt'] != null
            ? DateTime.tryParse(map['countdownEndsAt'])
            : null,
        questionStartAtMs: (map['questionStartAtMs'] as num?)?.toInt(),
        questionDurationSeconds:
        (map['questionDurationSeconds'] as num?)?.toInt(),
      );
}

class PlayerSession {
  final String playerId;
  final String name;
  final int score;
  final Map<String, String> answers;
  final int totalResponseTimeMs; // tiebreaker — lower = faster = better rank

  PlayerSession({
    required this.playerId,
    required this.name,
    required this.score,
    required this.answers,
    this.totalResponseTimeMs = 0,
  });

  Map<String, dynamic> toMap() => {
    'playerId': playerId,
    'name': name,
    'score': score,
    'answers': answers,
    'totalResponseTimeMs': totalResponseTimeMs,
  };

  factory PlayerSession.fromMap(Map<String, dynamic> map) => PlayerSession(
    playerId: map['playerId'],
    name: map['name'],
    score: map['score'] ?? 0,
    answers: Map<String, String>.from(map['answers'] ?? {}),
    totalResponseTimeMs:
    (map['totalResponseTimeMs'] as num?)?.toInt() ?? 0,
  );
}

// lib/data/models/question_model.dart

enum QuestionType { mcq, trueFalse }

class QuestionModel {
  final String id;
  final String question;
  final QuestionType type;
  final List<String> options;
  final List<String> correctAnswers;
  final int timeLimitSeconds;
  final int points;
  final String? imageUrl;
  final String? videoUrl;

  const QuestionModel({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
    this.correctAnswers = const [],
    this.timeLimitSeconds = 30,
    this.points = 1000,
    this.imageUrl,
    this.videoUrl,
  });

  bool get hasCorrectAnswer => correctAnswers.isNotEmpty;

  QuestionModel copyWith({
    String? id,
    String? question,
    QuestionType? type,
    List<String>? options,
    List<String>? correctAnswers,
    int? timeLimitSeconds,
    int? points,
    String? imageUrl,
    String? videoUrl,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      question: question ?? this.question,
      type: type ?? this.type,
      options: options ?? this.options,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      points: points ?? this.points,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      type: QuestionType.values.firstWhere(
            (t) => t.name == map['type'],
        orElse: () => QuestionType.mcq,
      ),
      options: List<String>.from(map['options'] ?? []),
      correctAnswers: List<String>.from(map['correctAnswers'] ?? []),
      timeLimitSeconds: map['timeLimitSeconds'] ?? 30,
      points: _parsePointsValue(map['points']),
      imageUrl: map['imageUrl'],
      videoUrl: map['videoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'type': type.name,
      'options': options,
      'correctAnswers': correctAnswers,
      'timeLimitSeconds': timeLimitSeconds,
      'points': points,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
    };
  }
}

/// Parses a stored `points` value into an int.
///
/// Supports the new numeric format (10/100/1000) and is backward compatible
/// with the legacy enum names that older quizzes saved
/// (none -> 0, standard -> 1000, double -> 2000).
int _parsePointsValue(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final n = int.tryParse(raw.trim());
    if (n != null) return n;
    switch (raw.toLowerCase()) {
      case 'none':
        return 0;
      case 'double':
        return 2000;
      case 'standard':
        return 1000;
    }
  }
  return 1000;
}

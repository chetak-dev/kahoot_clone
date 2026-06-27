// lib/data/models/question_model.dart

enum QuestionType { mcq, trueFalse }

enum PointsType { none, standard, double }

class QuestionModel {
  final String id;
  final String question;
  final QuestionType type;
  final List<String> options;
  final List<String> correctAnswers;
  final int timeLimitSeconds;
  final PointsType points;
  final String? imageUrl;
  final String? videoUrl;

  const QuestionModel({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
    this.correctAnswers = const [],
    this.timeLimitSeconds = 30,
    this.points = PointsType.standard,
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
    PointsType? points,
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
      points: PointsType.values.firstWhere(
            (p) => p.name == map['points'],
        orElse: () => PointsType.standard,
      ),
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
      'points': points.name,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
    };
  }
}

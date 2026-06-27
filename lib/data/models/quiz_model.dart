import 'question_model.dart';

class QuizModel {
  final String id;
  final String title;
  final String description;
  final String creatorId;
  final String? coverImageUrl;
  final List<QuestionModel> questions;
  final DateTime createdAt;
  final bool isPublic;

  QuizModel({
    required this.id,
    required this.title,
    required this.description,
    required this.creatorId,
    this.coverImageUrl,
    required this.questions,
    required this.createdAt,
    this.isPublic = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'creatorId': creatorId,
    'coverImageUrl': coverImageUrl,
    'questions': questions.map((q) => q.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'isPublic': isPublic,
  };

  factory QuizModel.fromMap(Map<String, dynamic> map) => QuizModel(
    id: map['id'],
    title: map['title'],
    description: map['description'],
    creatorId: map['creatorId'],
    coverImageUrl: map['coverImageUrl'],
    questions: (map['questions'] as List)
        .map((q) => QuestionModel.fromMap(q))
        .toList(),
    createdAt: DateTime.parse(map['createdAt']),
    isPublic: map['isPublic'] ?? false,
  );
}
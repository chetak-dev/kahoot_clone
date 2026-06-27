// lib/presentation/home/quiz_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/question_model.dart';
import '../../data/models/quiz_model.dart';

class QuizDetailScreen extends StatelessWidget {
  final QuizModel quiz;
  const QuizDetailScreen({super.key, required this.quiz});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/my-quizzes');
            }
          },
        ),
        title: Text(quiz.title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Edit quiz',
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => context.push('/edit-quiz', extra: quiz),
          ),
          if (quiz.questions.isNotEmpty)
            IconButton(
              tooltip: 'Host this quiz',
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              onPressed: () => context.go('/host-game', extra: quiz),
            ),
        ],

      ),
      body: quiz.questions.isEmpty
          ? const Center(
        child: Text('This quiz has no questions yet.',
            style: TextStyle(color: Colors.white54)),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: quiz.questions.length,
        itemBuilder: (context, index) => _QuestionCard(
          index: index,
          question: quiz.questions[index],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final QuestionModel question;
  const _QuestionCard({required this.index, required this.question});

  @override
  Widget build(BuildContext context) {
    // True/False questions may store empty options, so fall back to True/False.
    final options =
    (question.type == QuestionType.trueFalse && question.options.isEmpty)
        ? const ['True', 'False']
        : question.options;

    final correctLower =
    question.correctAnswers.map((a) => a.toLowerCase()).toSet();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: question number + type chip
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.accent,
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const SizedBox(width: 10),
              _chip(_typeLabel(question.type)),
            ],
          ),
          const SizedBox(height: 12),

          // Question text
          Text(question.question,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Meta info: time limit + points (own row so it never overflows)
          Row(
            children: [
              const Icon(Icons.timer, size: 16, color: Colors.white54),
              const SizedBox(width: 4),
              Text('${question.timeLimitSeconds}s',
                  style:
                  const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 16),
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(_pointsLabel(question.points),
                  style:
                  const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),

          // Options / answer
          if (options.isEmpty)
            Text(
              question.correctAnswers.isNotEmpty
                  ? 'Answer: ${question.correctAnswers.join(', ')}'
                  : 'No options',
              style: const TextStyle(color: Colors.white70),
            )
          else
            ...options.map((opt) {
              final isCorrect = correctLower.contains(opt.toLowerCase());
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withOpacity(0.18)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isCorrect ? Colors.green : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(
                        isCorrect
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: isCorrect ? Colors.green : Colors.white38),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(opt,
                            style: const TextStyle(color: Colors.white))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600)),
  );

  String _typeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.mcq:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True / False';
    }
  }

  String _pointsLabel(PointsType points) {
    switch (points) {
      case PointsType.none:
        return 'No points';
      case PointsType.standard:
        return '1000 pts';
      case PointsType.double:
        return '2000 pts';
    }
  }
}

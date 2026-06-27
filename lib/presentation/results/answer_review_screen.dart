// lib/presentation/results/answer_review_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/question_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/services/game_provider.dart';
import '../../core/utils/nav_helpers.dart';


class AnswerReviewScreen extends ConsumerWidget {
  final String pin;
  const AnswerReviewScreen({super.key, required this.pin});

  bool _isCorrect(QuestionModel q, String? answer) {
    if (answer == null) return false;
    return q.correctAnswers
        .map((a) => a.toLowerCase())
        .contains(answer.toLowerCase());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameSessionProvider(pin));
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        goHome(context, ref);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          automaticallyImplyLeading: false,
          title: const Text('Your Answers',
              style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: gameAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.accent)),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: Colors.white))),
          data: (session) {
            if (session == null) return _ended(context, ref);
            return FutureBuilder<QuizModel?>(
              future: GameRepository().getQuizForGame(session.quizId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child:
                      CircularProgressIndicator(color: AppTheme.accent));
                }
                final quiz = snapshot.data!;
                final player = uid == null ? null : session.players[uid];
                final answers = player?.answers ?? const <String, String>{};

                var correctCount = 0;
                for (final q in quiz.questions) {
                  if (_isCorrect(q, answers[q.id])) correctCount++;
                }

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'You got $correctCount / ${quiz.questions.length} correct',
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          if (player != null) ...[
                            const SizedBox(height: 4),
                            Text('Score: ${player.score} pts',
                                style:
                                const TextStyle(color: Colors.white70)),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: quiz.questions.length,
                        itemBuilder: (context, index) {
                          final q = quiz.questions[index];
                          final yourAnswer = answers[q.id];
                          return _ReviewCard(
                            index: index + 1,
                            question: q.question,
                            yourAnswer: yourAnswer,
                            correctAnswer: q.correctAnswers.join(', '),
                            isCorrect: _isCorrect(q, yourAnswer),
                            answered: yourAnswer != null,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.go('/results/$pin'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side:
                                const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                              child: const Text('Final Results'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => goHome(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                              child: const Text('Home',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _ended(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Game over!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => goHome(context, ref) ,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final int index;
  final String question;
  final String? yourAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final bool answered;

  const _ReviewCard({
    required this.index,
    required this.question,
    required this.yourAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.answered,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
    !answered ? Colors.white38 : (isCorrect ? Colors.green : Colors.red);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Q$index. ',
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(question,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(
                !answered
                    ? Icons.remove_circle_outline
                    : (isCorrect ? Icons.check_circle : Icons.cancel),
                color: statusColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row('Your answer',
              answered ? (yourAnswer ?? '') : 'Not answered', statusColor),
          const SizedBox(height: 4),
          _row('Correct answer', correctAnswer, Colors.green),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// lib/presentation/game_play/player_question_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_session_model.dart';
import '../../data/models/question_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/services/game_provider.dart';
import '../../data/models/quiz_model.dart';
import 'dart:math';


class PlayerQuestionScreen extends ConsumerStatefulWidget {
  final String pin;
  const PlayerQuestionScreen({super.key, required this.pin});

  @override
  ConsumerState<PlayerQuestionScreen> createState() =>
      _PlayerQuestionScreenState();
}

class _PlayerQuestionScreenState
    extends ConsumerState<PlayerQuestionScreen> {
  Timer? _fallbackTimer;

  // ✅ Fixed: track selected option as String, not AnswerOption ID
  String? _selectedAnswer;
  bool _answered = false;
  int _timeLeft = 20;
  Timer? _timer;
  int _lastQuestionIndex = -1;

  final List<Color> _optionColors = [
    Colors.red,
    Colors.blue,
    Colors.yellow,
    Colors.green,
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }


  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _timeLeft = seconds;
      _answered = false;
      _selectedAnswer = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _scheduleFallback(int questionIndex, int limit) {
    _fallbackTimer?.cancel();
    // If the host hasn't moved the game on (e.g., app backgrounded), a player
    // pushes it to the leaderboard after the question time + a small grace.
    final delay = (limit * 1000) + 2000 + Random().nextInt(1500);
    _fallbackTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      final session = ref.read(gameSessionProvider(widget.pin)).valueOrNull;
      if (session != null &&
          session.status == GameStatus.question &&
          session.currentQuestion == questionIndex) {
        ref.read(gameNotifierProvider.notifier).showLeaderboard(widget.pin);
      }
    });
  }


  // ✅ Fixed: takes String answer instead of AnswerOption
  Future<void> _submitAnswer(
      String questionId,
      String answer,
      QuestionModel question) async {
    if (_answered) return;

    setState(() {
      _answered = true;
      _selectedAnswer = answer;
    });

    // ✅ Fixed: check correctness using correctAnswers list
    final isCorrect = question.correctAnswers
        .map((a) => a.toLowerCase())
        .contains(answer.toLowerCase());

    // ✅ Fixed: convert PointsType to int for scoring
    final maxPoints = _pointsValue(question.points);
    final earnedPoints = isCorrect ? maxPoints : 0;

    await ref.read(gameNotifierProvider.notifier).submitAnswer(
      widget.pin,
      questionId,
      answer,
      earnedPoints,
    );
  }

  // ✅ Fixed: convert PointsType enum to int
  int _pointsValue(PointsType points) {
    switch (points) {
      case PointsType.none:
        return 0;
      case PointsType.standard:
        return 1000;
      case PointsType.double:
        return 2000;
    }
  }

  bool _isCorrectAnswer(QuestionModel question, String answer) {
    return question.correctAnswers
        .map((a) => a.toLowerCase())
        .contains(answer.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameSessionProvider(widget.pin));

    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final leave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.background,
              title: const Text('Leave game?',
                  style: TextStyle(color: Colors.white)),
              content: const Text('You will exit the current game.',
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Stay',
                        style: TextStyle(color: Colors.white54))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Leave',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (leave == true && mounted) context.go('/');
        },
        child: gameAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.primary,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.accent)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.primary,
        body: Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white))),
      ),
      data: (session) {
        if (session == null) {
          return const Scaffold(
            backgroundColor: AppTheme.primary,
            body: Center(
                child: Text('Session ended',
                    style: TextStyle(color: Colors.white))),
          );
        }

        if (session.status == GameStatus.leaderboard) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/leaderboard/${widget.pin}');
          });
        }
        if (session.status == GameStatus.ended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/${widget.pin}');
          });
        }

        return FutureBuilder<QuizModel?>(
          future: GameRepository().getQuizForGame(session.quizId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                backgroundColor: AppTheme.primary,
                body: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.accent)),
              );
            }

            final quiz = snapshot.data!;
            final question = quiz.questions[session.currentQuestion];

            // Start timer when question changes
            if (_lastQuestionIndex != session.currentQuestion) {
              _lastQuestionIndex = session.currentQuestion;
              final qIndex = session.currentQuestion;
              final limit = question.timeLimitSeconds;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _startTimer(limit);
                _scheduleFallback(qIndex, limit);
              });
            }


            return Scaffold(
              backgroundColor: AppTheme.background,
              body: SafeArea(
                child: Column(
                  children: [
                    // Timer bar
                    // ✅ Fixed: use timeLimitSeconds
                    LinearProgressIndicator(
                      value: _timeLeft / question.timeLimitSeconds,
                      backgroundColor: Colors.white24,
                      color: _timeLeft > 5
                          ? Colors.green
                          : Colors.red,
                      minHeight: 8,
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Q${session.currentQuestion + 1}/${quiz.questions.length}',
                                style: const TextStyle(
                                    color: Colors.white70),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _timeLeft > 5
                                      ? Colors.green
                                      : Colors.red,
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_timeLeft',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Question text
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              question.question,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Answer area
                    Expanded(
                      child: _answered
                          ? _buildAnsweredView(question)
                          : _buildOptionsView(question),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
        ),
    );
  }

  // ── After answering: show correct/wrong feedback ───────────────────────────
  Widget _buildAnsweredView(QuestionModel question) {
    // ✅ Fixed: check correctness using correctAnswers list
    final isCorrect = _selectedAnswer != null &&
        _isCorrectAnswer(question, _selectedAnswer!);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 80,
            color: isCorrect ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            isCorrect ? 'Correct! 🎉' : 'Wrong!',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          if (!isCorrect && question.correctAnswers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Answer: ${question.correctAnswers.join(', ')}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Waiting for next question...',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  // ── Options grid ───────────────────────────────────────────────────────────
  Widget _buildOptionsView(QuestionModel question) {
    // Poll: no correct answer, just submit selection
    // MCQ / TrueFalse: submit and check
    final options = question.type == QuestionType.trueFalse
        ? ['True', 'False']
        : question.options;

    if (options.isEmpty) {
      return const Center(
        child: Text('No options available',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: options.asMap().entries.map((e) {
          final index = e.key;
          final option = e.value;
          return GestureDetector(
            onTap: () => _submitAnswer(
              question.id,
              option,
              question,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _optionColors[index % _optionColors.length],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
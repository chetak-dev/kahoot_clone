// lib/presentation/game_play/player_question_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/nav_helpers.dart';
import '../../data/models/game_session_model.dart';
import '../../data/models/question_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/services/game_provider.dart';

class PlayerQuestionScreen extends ConsumerStatefulWidget {
  final String pin;
  const PlayerQuestionScreen({super.key, required this.pin});

  @override
  ConsumerState<PlayerQuestionScreen> createState() =>
      _PlayerQuestionScreenState();
}

class _PlayerQuestionScreenState extends ConsumerState<PlayerQuestionScreen> {
  String? _selectedAnswer; // tentative selection (changeable until submit)
  bool _answered = false; // locked in
  int _timeLeft = 0;
  Timer? _ticker;
  Timer? _fallbackTimer;
  int _lastQuestionIndex = -1;
  QuestionModel? _currentQuestion;
  int? _startAtMs;          // server timestamp when the question started
  int _durationSeconds = 0; // question time limit
  int _serverOffsetMs = 0;  // this device's clock vs Firebase server clock

  @override
  void initState() {
    super.initState();
    GameRepository().getServerTimeOffset().then((v) {
      if (mounted) setState(() => _serverOffsetMs = v);
    });
  }

  final List<Color> _optionColors = [
    Colors.red,
    Colors.blue,
    Colors.orange,
    Colors.green,
  ];

  @override
  void dispose() {
    _ticker?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

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

  int _computeRemaining() {
    if (_startAtMs == null) return _durationSeconds;
    final serverNow = DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;
    final endsAtMs = _startAtMs! + _durationSeconds * 1000;
    return ((endsAtMs - serverNow) / 1000).ceil().clamp(0, 999);
  }

  // Count down to the server-stamped start so host & players match exactly.
  void _startTimer(
      GameSessionModel session, QuestionModel question, int questionIndex) {
    _ticker?.cancel();
    _fallbackTimer?.cancel();
    _currentQuestion = question;
    _startAtMs = session.questionStartAtMs;
    _durationSeconds =
        session.questionDurationSeconds ?? question.timeLimitSeconds;
    setState(() {
      _answered = false;
      _selectedAnswer = null;
      _timeLeft = _computeRemaining();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) return;
      final left = _computeRemaining();
      if (left != _timeLeft) setState(() => _timeLeft = left);
      if (left <= 0) {
        t.cancel();
        if (!_answered) _lockIn(auto: true);
        _scheduleFallback(questionIndex);
      }
    });
  }


  void _scheduleFallback(int questionIndex) {
    _fallbackTimer?.cancel();
    final delay = 2000 + Random().nextInt(1500);
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

  Future<void> _lockIn({bool auto = false}) async {
    if (_answered) return;
    final question = _currentQuestion;
    setState(() => _answered = true);
    final answer = _selectedAnswer;
    if (question == null || answer == null) return; // timed out, no choice
    final isCorrect = question.correctAnswers
        .map((a) => a.toLowerCase())
        .contains(answer.toLowerCase());
    final earned = isCorrect ? _pointsValue(question.points) : 0;
    await ref.read(gameNotifierProvider.notifier).submitAnswer(
      widget.pin,
      question.id,
      answer,
      earned,
    );
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
        if (leave == true && mounted) goHome(context, ref);
      },
      child: gameAsync.when(
        loading: () => const Scaffold(
          backgroundColor: AppTheme.primary,
          body:
          Center(child: CircularProgressIndicator(color: AppTheme.accent)),
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
                      child:
                      CircularProgressIndicator(color: AppTheme.accent)),
                );
              }

              final quiz = snapshot.data!;
              final question = quiz.questions[session.currentQuestion];
              final total = question.timeLimitSeconds;

              if (_lastQuestionIndex != session.currentQuestion) {
                _lastQuestionIndex = session.currentQuestion;
                final qIndex = session.currentQuestion;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startTimer(session, question, qIndex);
                });
              }


              return Scaffold(
                backgroundColor: AppTheme.background,
                body: SafeArea(
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value:
                        total == 0 ? 0 : (_timeLeft / total).clamp(0, 1),
                        backgroundColor: Colors.white24,
                        color: _timeLeft > 5 ? Colors.green : Colors.red,
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
                                  style:
                                  const TextStyle(color: Colors.white70),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _timeLeft > 5
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('$_timeLeft',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
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
                      Expanded(
                        child: _answered
                            ? _buildLockedView()
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

  // ── Locked-in view: shows the selection only — never correctness ──
  Widget _buildLockedView() {
    final hasAnswer = _selectedAnswer != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasAnswer ? Icons.lock_rounded : Icons.timer_off_rounded,
                size: 72, color: AppTheme.accent),
            const SizedBox(height: 16),
            Text(
              hasAnswer ? 'Answer locked in!' : "Time's up!",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            if (hasAnswer) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text('You selected: $_selectedAnswer',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text("You didn't answer this one.",
                    style: TextStyle(color: Colors.white54)),
              ),
            const SizedBox(height: 20),
            const Text('Waiting for next question...',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  // ── Options: tap to select (changeable), then Submit ──
  Widget _buildOptionsView(QuestionModel question) {
    final options = question.type == QuestionType.trueFalse
        ? ['True', 'False']
        : question.options;

    if (options.isEmpty) {
      return const Center(
        child: Text('No options available',
            style: TextStyle(color: Colors.white54)),
      );
    }

    // Fixed-height tiles — never stretches on large screens, scrolls on tiny ones
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          ...options.asMap().entries.map((e) {
            final index = e.key;
            final option = e.value;
            final isSelected = _selectedAnswer == option;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedAnswer = option),
                child: Container(
                  height: 64,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _optionColors[index % _optionColors.length],
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 4)
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
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
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('✓',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedAnswer == null ? null : () => _lockIn(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white24,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _selectedAnswer == null ? 'Select an option' : 'Submit Answer',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

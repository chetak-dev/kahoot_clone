// lib/presentation/game_play/player_question_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/nav_helpers.dart';
import '../../core/widgets/gradient_button.dart';
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
  String? _selectedAnswer;
  bool _answered = false;
  int _timeLeft = 0;
  Timer? _ticker;
  Timer? _fallbackTimer;
  int _lastQuestionIndex = -1;
  QuestionModel? _currentQuestion;
  int? _startAtMs;
  int? _localStartMs; // wall-clock fallback if the server timestamp is missing
  int _durationSeconds = 0;
  int _serverOffsetMs = 0;

  static const _labels = ['A', 'B', 'C', 'D'];
  static const _labelColors = [
    Color(0xFFE57373), // soft red
    Color(0xFF64B5F6), // soft blue
    Color(0xFFFFB74D), // soft amber
    Color(0xFF81C784), // soft green
  ];

  StreamSubscription? _offsetSub;

  @override
  void initState() {
    super.initState();
    // Stay in sync with server clock continuously
    _offsetSub = GameRepository().watchServerTimeOffset().listen((offset) {
      if (mounted) setState(() => _serverOffsetMs = offset);
    });
  }

  @override
  void dispose() {
    _offsetSub?.cancel();
    _ticker?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  int _computeRemaining() {
    // Prefer the server-synced start; fall back to a local start so the
    // countdown can never stall (which would freeze the whole game).
    final startMs = _startAtMs ?? _localStartMs;
    if (startMs == null) return _durationSeconds;
    // Only correct for server-clock drift when using the server timestamp.
    final now = DateTime.now().millisecondsSinceEpoch +
        (_startAtMs != null ? _serverOffsetMs : 0);
    final endsAtMs = startMs + _durationSeconds * 1000;
    return ((endsAtMs - now) / 1000).ceil().clamp(0, 999);
  }

  void _startTimer(
      GameSessionModel session, QuestionModel question, int questionIndex) {
    _ticker?.cancel();
    _fallbackTimer?.cancel();
    _currentQuestion = question;
    _startAtMs = session.questionStartAtMs;
    _localStartMs = DateTime.now().millisecondsSinceEpoch;
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
    setState(() => _answered = true);

    // Timer ran out — user never clicked Submit, selection doesn't count
    if (auto) return;

    final question = _currentQuestion;
    final answer = _selectedAnswer;
    if (question == null || answer == null) return;

    // How fast the player answered (capped at the question duration)
    final responseTimeMs = _startAtMs != null
        ? (DateTime.now().millisecondsSinceEpoch + _serverOffsetMs - _startAtMs!)
        .clamp(0, _durationSeconds * 1000)
        : _durationSeconds * 1000;

    final isCorrect = question.correctAnswers
        .map((a) => a.toLowerCase())
        .contains(answer.toLowerCase());
    final earned = isCorrect ? question.points : 0;

    await ref.read(gameNotifierProvider.notifier).submitAnswer(
      widget.pin,
      question.id,
      answer,
      earned,
      responseTimeMs,
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
              final total = question.timeLimitSeconds;

              if (_lastQuestionIndex != session.currentQuestion) {
                _lastQuestionIndex = session.currentQuestion;
                final qIndex = session.currentQuestion;
                // Start the countdown right away. The server-clock offset is
                // kept current by the watchServerTimeOffset() listener set up
                // in initState; blocking on a one-off fetch can hang on the
                // synthetic .info node and freeze the timer. Defer to after
                // this frame since _startTimer calls setState.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _startTimer(session, question, qIndex);
                });
              }

              return Scaffold(
                backgroundColor: AppTheme.background,
                body: SafeArea(
                  child: Column(
                    children: [
                      // Progress bar
                      LinearProgressIndicator(
                        value: total == 0
                            ? 0
                            : (_timeLeft / total).clamp(0, 1),
                        backgroundColor: Colors.white24,
                        color: _timeLeft > 5 ? Colors.green : Colors.red,
                        minHeight: 8,
                      ),

                      // Question header
                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                                  child: Text('$_timeLeft',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                question.question,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Options or locked view
                      Expanded(
                        child: _answered
                            ? _buildLockedView()
                            : _buildOptionsView(question),
                      ),

                      // Submit button pinned at bottom
                      if (!_answered)
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: GradientButton(
                            onPressed: _selectedAnswer == null
                                ? null
                                : () => _lockIn(),
                            verticalPadding: 14,
                            borderRadius: 10,
                            child: Text(
                              _selectedAnswer == null
                                  ? 'Select an option'
                                  : 'Submit Answer',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: options.asMap().entries.map((e) {
          final index = e.key;
          final option = e.value;
          final isSelected = _selectedAnswer == option;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedAnswer = option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 52),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent.withOpacity(0.12)
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accent
                        : Colors.white.withOpacity(0.15),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accent
                              : _labelColors[index % _labelColors.length]
                              .withOpacity(0.25),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(9),
                            bottomLeft: Radius.circular(9),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _labels[index % _labels.length],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.black
                                  : _labelColors[index % _labelColors.length],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Center(
                            child: Text(
                              option,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                isSelected ? AppTheme.accent : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Center(
                            child: Icon(Icons.check_circle_rounded,
                                color: AppTheme.accent, size: 20),
                          ),
                        )
                      else
                        const SizedBox(width: 36),
                    ],
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

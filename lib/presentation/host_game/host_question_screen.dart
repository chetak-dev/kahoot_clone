import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_session_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/services/game_provider.dart';
import '../game_play/countdown_view.dart';

class HostQuestionScreen extends ConsumerStatefulWidget {
  final String pin;
  const HostQuestionScreen({super.key, required this.pin});

  @override
  ConsumerState<HostQuestionScreen> createState() =>
      _HostQuestionScreenState();
}

class _HostQuestionScreenState extends ConsumerState<HostQuestionScreen> {
  int _timeLeft = 20;
  Timer? _timer;
  int _lastQuestionIndex = -1;
  bool _timerDone = false;
  int? _startAtMs;
  int? _localStartMs; // wall-clock fallback if the server timestamp is missing
  int _durationSeconds = 0;
  int _serverOffsetMs = 0;

  StreamSubscription? _offsetSub;

  // Used only on the rejoin path: if a host re-enters this screen while the
  // game is still in the pre-game countdown, advance to the first question
  // once the countdown elapses (guarded so it only fires once).
  Timer? _countdownWatch;
  bool _countdownAdvanced = false;

  // Cache the quiz fetch so it isn't re-issued on every rebuild.
  // The quizId is fixed for the whole game, so a single fetch is enough.
  Future<QuizModel?>? _quizFuture;
  String? _quizFutureId;

  Future<QuizModel?> _quizFor(String quizId) {
    if (_quizFuture == null || _quizFutureId != quizId) {
      _quizFutureId = quizId;
      _quizFuture = GameRepository().getQuizForGame(quizId);
    }
    return _quizFuture!;
  }

  @override
  void initState() {
    super.initState();
    // Stay in sync with server clock continuously
    _offsetSub = GameRepository().watchServerTimeOffset().listen((offset) {
      if (mounted) setState(() => _serverOffsetMs = offset);
    });
    // Rejoin safety-net: advance the pre-game countdown if the host lands here
    // while it's still running. During a normal game the host enters this
    // screen only once the question has started, so this stays a no-op then.
    _countdownWatch =
        Timer.periodic(const Duration(milliseconds: 500), (_) => _maybeStartFirstQuestion());
  }

  Future<void> _maybeStartFirstQuestion() async {
    if (_countdownAdvanced) return;
    final session = ref.read(gameSessionProvider(widget.pin)).valueOrNull;
    if (session == null || session.status != GameStatus.countdown) return;
    final endsAt = session.countdownEndsAt;
    if (endsAt == null || DateTime.now().isBefore(endsAt)) return;

    _countdownAdvanced = true;
    final quiz = await _quizFor(session.quizId);
    if (quiz == null || quiz.questions.isEmpty) {
      _countdownAdvanced = false; // let it retry once the quiz loads
      return;
    }
    // Re-check: a participant may have advanced it while we awaited the quiz.
    final current = ref.read(gameSessionProvider(widget.pin)).valueOrNull;
    if (current == null || current.status != GameStatus.countdown) return;

    await ref.read(gameNotifierProvider.notifier).nextQuestion(
      widget.pin,
      0,
      durationSeconds: quiz.questions.first.timeLimitSeconds,
    );
  }

  @override
  void dispose() {
    _offsetSub?.cancel();
    _countdownWatch?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(GameSessionModel session, int totalSeconds) {
    _timer?.cancel();
    _startAtMs = session.questionStartAtMs;
    _localStartMs = DateTime.now().millisecondsSinceEpoch;
    _durationSeconds = session.questionDurationSeconds ?? totalSeconds;
    setState(() {
      _timeLeft = _computeRemaining();
      _timerDone = false;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) return;
      final left = _computeRemaining();
      if (left != _timeLeft) setState(() => _timeLeft = left);
      if (left <= 0) {
        t.cancel();
        if (!_timerDone) {
          setState(() => _timerDone = true);
          ref.read(gameNotifierProvider.notifier).showLeaderboard(widget.pin);
        }
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameSessionProvider(widget.pin));

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final end = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.background,
            title: const Text('End game?',
                style: TextStyle(color: Colors.white)),
            content: const Text(
                'This will end the game for all players.',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('End',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (end == true) {
          await ref.read(gameNotifierProvider.notifier).endGame(widget.pin);
          if (mounted) context.go('/');
        }
      },
      child: gameAsync.when(
        loading: () => const Scaffold(
          backgroundColor: AppTheme.primary,
          body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
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

          // Rejoin path: the host re-entered while the game hasn't reached the
          // first question yet. Show the shared countdown (it advances via
          // _maybeStartFirstQuestion / participants) rather than the question UI.
          if (session.status == GameStatus.countdown) {
            return CountdownView(
              endsAt: session.countdownEndsAt ??
                  DateTime.now().add(const Duration(seconds: 60)),
              title: 'Starting in...',
            );
          }
          if (session.status == GameStatus.lobby) {
            return const Scaffold(
              backgroundColor: AppTheme.primary,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accent),
                    SizedBox(height: 16),
                    Text('Waiting in lobby…',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            );
          }

          return FutureBuilder<QuizModel?>(
            future: _quizFor(session.quizId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(
                  backgroundColor: AppTheme.primary,
                  body: Center(
                      child: CircularProgressIndicator(color: AppTheme.accent)),
                );
              }

              final quiz = snapshot.data!;
              final question = quiz.questions[session.currentQuestion];
              final answeredCount = session.players.values
                  .where((p) => p.answers.containsKey(question.id))
                  .length;

              if (_lastQuestionIndex != session.currentQuestion) {
                _lastQuestionIndex = session.currentQuestion;
                // Start the countdown right away. The server-clock offset is
                // kept current by the watchServerTimeOffset() listener set up in
                // initState, so we must NOT block timer start on a one-off fetch
                // (which can hang on the synthetic .info node and freeze the
                // timer). Defer to after this frame since _startTimer calls
                // setState.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _startTimer(session, question.timeLimitSeconds);
                });
              }

              final isLast =
                  session.currentQuestion == quiz.questions.length - 1;

              return Scaffold(
                backgroundColor: AppTheme.background,
                body: SafeArea(
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: question.timeLimitSeconds == 0
                            ? 0
                            : _timeLeft / question.timeLimitSeconds,
                        backgroundColor: Colors.white24,
                        color: _timeLeft > 5
                            ? AppTheme.correct
                            : AppTheme.incorrect,
                        minHeight: 8,
                      ),

                      // Scrollable middle so long questions never overflow
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Q${session.currentQuestion + 1}/${quiz.questions.length}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _timeLeft > 5
                                          ? AppTheme.correct
                                          : AppTheme.incorrect,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('$_timeLeft',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '$answeredCount/${session.players.length} answered',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  question.question,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 16),

                              Column(
                                children: question.options.asMap().entries.map((e) {
                                  final colors = [
                                    Colors.red,
                                    Colors.blue,
                                    Colors.yellow,
                                    Colors.green,
                                  ];
                                  final isCorrect =
                                  question.correctAnswers.contains(e.value);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: double.infinity,
                                      constraints: const BoxConstraints(
                                          minHeight: 56),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _timerDone && isCorrect
                                            ? AppTheme.correct
                                            : colors[e.key % colors.length]
                                            .withOpacity(
                                            _timerDone && !isCorrect
                                                ? 0.3
                                                : 1.0),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        child: Text(
                                          e.value,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _timerDone && !isCorrect
                                                ? Colors.white38
                                                : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );

                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _timerDone
                              ? 'Showing leaderboard…'
                              : 'Players are answering…',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54),
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
}

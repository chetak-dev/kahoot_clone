import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_session_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/services/game_provider.dart';
import '../game_play/countdown_view.dart';
import '../../core/widgets/back_guard.dart';

class PlayerLobbyScreen extends ConsumerStatefulWidget {
  final String pin;
  const PlayerLobbyScreen({super.key, required this.pin});

  @override
  ConsumerState<PlayerLobbyScreen> createState() => _PlayerLobbyScreenState();
}

class _PlayerLobbyScreenState extends ConsumerState<PlayerLobbyScreen> {
  // Staggered grace so multiple participants don't all fire at once when the
  // host is gone. Mirrors the fallback used on the leaderboard screen.
  final int _fallbackDelayMs = 2000 + Random().nextInt(1500);

  Timer? _ticker;
  bool _advanced = false;
  QuizModel? _quiz;

  @override
  void initState() {
    super.initState();
    // Watch the wall clock so the countdown can advance to the first question
    // even if the host drops off during it.
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_advanced) return;
    final session = ref.read(gameSessionProvider(widget.pin)).valueOrNull;
    if (session == null || session.status != GameStatus.countdown) return;

    final endsAt = session.countdownEndsAt;
    if (endsAt == null) return;

    // Cache the quiz once so we know the first question's time limit.
    _quiz ??= await GameRepository().getQuizForGame(session.quizId);
    if (_quiz == null || _quiz!.questions.isEmpty) return;

    // Re-read after the await; the host may have advanced in the meantime.
    final current = ref.read(gameSessionProvider(widget.pin)).valueOrNull;
    if (_advanced || current == null || current.status != GameStatus.countdown) {
      return;
    }

    final isHost = session.hostId == FirebaseAuth.instance.currentUser?.uid;
    final msPast = DateTime.now().difference(endsAt).inMilliseconds;

    // Host advances on time; any participant advances after a short grace so
    // the quiz starts even if the host app is backgrounded/closed.
    final canAdvance = isHost ? msPast >= 0 : msPast >= _fallbackDelayMs;
    if (!canAdvance) return;

    _advanced = true;
    await ref.read(gameNotifierProvider.notifier).nextQuestion(
      widget.pin,
      0,
      durationSeconds: _quiz!.questions.first.timeLimitSeconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameSessionProvider(widget.pin));

    return BackGuard(
      destination: '/',
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

          // Countdown screen (synced with host)
          if (session.status == GameStatus.countdown) {
            return CountdownView(
              endsAt: session.countdownEndsAt ??
                  // Fallback only; the real end time comes from the host via
                  // countdownEndsAt. Kept at 60s to match the host countdown.
                  DateTime.now().add(const Duration(seconds: 60)),
              title: 'Get Ready!',
            );
          }

          // Navigate based on status
          if (session.status == GameStatus.question) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/player-question/${widget.pin}');
            });
          } else if (session.status == GameStatus.leaderboard) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/leaderboard/${widget.pin}');
            });
          } else if (session.status == GameStatus.ended) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/results/${widget.pin}');
            });
          }

          return Scaffold(
            backgroundColor: AppTheme.primary,
            appBar: AppBar(
              backgroundColor: AppTheme.primary,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  await ref
                      .read(gameNotifierProvider.notifier)
                      .leaveGame(widget.pin);
                  if (context.mounted) context.go('/join-game');
                },
              ),

              title: const Text('Waiting for Host',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.hourglass_top_rounded,
                                size: 64, color: AppTheme.accent),
                            const SizedBox(height: 24),
                            const Text(
                              'You\'re in!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Waiting for host to start...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 48),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${session.players.length}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Text('Players Joined',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          );
        },
      ),
    );
  }
}

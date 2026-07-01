import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_result_model.dart';
import '../../data/models/game_session_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/services/game_provider.dart';
import 'dart:math';


class LeaderboardScreen extends ConsumerStatefulWidget {
  final String pin;
  const LeaderboardScreen({super.key, required this.pin});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final int _fallbackDelayMs = 2000 + Random().nextInt(1500); // stagger players

  Timer? _ticker;
  bool _advanced = false;
  bool _saving = false;
  QuizModel? _quiz;
  int _secondsLeft = 5;

  @override
  void initState() {
    super.initState();
    _ticker =
        Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final session = ref.read(gameSessionProvider(widget.pin)).valueOrNull;
    if (session == null || session.status != GameStatus.leaderboard) return;

    final endsAt = session.countdownEndsAt;
    final secs =
    endsAt == null ? 5 : endsAt.difference(DateTime.now()).inSeconds;
    final clamped = secs < 0 ? 0 : secs;
    if (clamped != _secondsLeft && mounted) {
      setState(() => _secondsLeft = clamped);
    }

    _quiz ??= await GameRepository().getQuizForGame(session.quizId);
    if (_quiz == null) return;

    if (_advanced || endsAt == null || _quiz == null) return;

    final isHost = session.hostId == FirebaseAuth.instance.currentUser?.uid;
    final msPast = DateTime.now().difference(endsAt).inMilliseconds;

    // Host advances on time; any participant advances after a short grace so
    // the game continues even if the host app is backgrounded/closed.
    final canAdvance = isHost ? msPast >= 0 : msPast >= _fallbackDelayMs;
    if (!canAdvance) return;

    _advanced = true;
    final isLast = session.currentQuestion >= _quiz!.questions.length - 1;
    if (isLast) {
      if (isHost) await _saveResults(session, _quiz!); // only host may save (rules)
      await ref.read(gameNotifierProvider.notifier).endGame(widget.pin);
    } else {
      await ref.read(gameNotifierProvider.notifier).nextQuestion(
        widget.pin,
        session.currentQuestion + 1,
        durationSeconds: _quiz!
            .questions[session.currentQuestion + 1].timeLimitSeconds,
      );

    }

  }

  Future<void> _saveResults(GameSessionModel session, QuizModel quiz) async {
    if (_saving) return;
    _saving = true;
    try {
      final sorted = session.players.values.toList()
        ..sort((a, b) {
          final scoreDiff = b.score.compareTo(a.score);
          if (scoreDiff != 0) return scoreDiff;
          // Tiebreaker: lower total response time = answered faster = wins
          return a.totalResponseTimeMs.compareTo(b.totalResponseTimeMs);
        });

      final result = GameResultModel(
        id: '${session.gamePin}_${DateTime.now().millisecondsSinceEpoch}',
        hostId: session.hostId,
        quizId: quiz.id,
        quizTitle: quiz.title,
        playedAt: DateTime.now(),
        playerCount: sorted.length,
        entries: sorted
            .map((p) => ResultEntry(name: p.name, score: p.score))
            .toList(),
      );
      await GameRepository().saveGameResult(result);
    } catch (_) {
      // Don't block game end if saving fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameSessionProvider(widget.pin));

    return PopScope(
      canPop: false,
      onPopInvoked: (_) {}, // leaderboard auto-advances; ignore back
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

          final isHost =
              session.hostId == FirebaseAuth.instance.currentUser?.uid;

          if (session.status == GameStatus.question) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(isHost
                  ? '/host-question/${widget.pin}'
                  : '/player-question/${widget.pin}');
            });
          } else if (session.status == GameStatus.ended) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/results/${widget.pin}');
            });
          }



          final sorted = session.players.values.toList()
            ..sort((a, b) {
              final scoreDiff = b.score.compareTo(a.score);
              if (scoreDiff != 0) return scoreDiff;
              // Tie on score → faster total response time ranks higher.
              return a.totalResponseTimeMs.compareTo(b.totalResponseTimeMs);
            });

          // How many players share each score. We only reveal the
          // response-time tiebreaker text when a score is actually tied.
          final scoreCounts = <int, int>{};
          for (final p in sorted) {
            scoreCounts[p.score] = (scoreCounts[p.score] ?? 0) + 1;
          }

          // The current participant, so we can highlight their own row.
          final myUid = FirebaseAuth.instance.currentUser?.uid;

          final isLast = _quiz != null &&

              session.currentQuestion >= _quiz!.questions.length - 1;

          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              backgroundColor: AppTheme.primary,
              automaticallyImplyLeading: false,
              title: const Text('Leaderboard 🏆',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            body: Column(
              children: [
                // "Next question in N" banner
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
                  ),
                  child: Text(
                    isLast
                        ? 'Final results in $_secondsLeft…'
                        : 'Next question in $_secondsLeft…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: sorted.isEmpty
                      ? const Center(
                    child: Text('No players',
                        style: TextStyle(color: Colors.white54)),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final player = sorted[index];
                      final medals = ['🥇', '🥈', '🥉'];
                      final isMe = myUid != null && player.playerId == myUid;
                      final isTied = (scoreCounts[player.score] ?? 0) > 1;
                      final responseSeconds =
                      (player.totalResponseTimeMs / 1000)
                          .toStringAsFixed(1);
                      // Distinct highlight for the current participant so they
                      // can find themselves without scanning the whole list.
                      const meColor = Color(0xFF4FC3F7);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isMe
                              ? meColor.withOpacity(0.22)
                              : index == 0
                              ? AppTheme.accent.withOpacity(0.2)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMe
                                ? meColor
                                : index == 0
                                ? AppTheme.accent
                                : Colors.transparent,
                            width: isMe ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              index < 3 ? medals[index] : '${index + 1}',
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(player.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: meColor,
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: const Text('You',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${player.score} pts',
                                    style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                // Reveal the tiebreaker only when this score is
                                // shared, so players understand the ordering.
                                if (isTied)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.bolt_rounded,
                                            size: 12, color: Colors.white54),
                                        const SizedBox(width: 2),
                                        Text('${responseSeconds}s',
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                                fontWeight:
                                                FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );

                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

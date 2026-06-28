import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_session_model.dart';
import '../../data/models/quiz_model.dart';
import '../../data/services/game_provider.dart';
import '../game_play/countdown_view.dart';
import '../../core/widgets/gradient_button.dart';


class HostGameScreen extends ConsumerStatefulWidget {
  final QuizModel quiz;
  const HostGameScreen({super.key, required this.quiz});

  @override
  ConsumerState<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends ConsumerState<HostGameScreen> {
  String? _pin;
  bool _isCreating = true;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _createGame() async {
    try {
      final pin = await ref
          .read(gameNotifierProvider.notifier)
          .createGame(widget.quiz);
      if (mounted) {
        setState(() {
          _pin = pin;
          _isCreating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create game: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        context.go('/my-quizzes');
      }
    }
  }

  Future<bool> _confirmEnd() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('End Game', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to end this game? All players will be disconnected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
            const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Game', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _startGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Start Game', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Start the game now? No new players will be able to join.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
            const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Begin the synced countdown for everyone.
    await ref.read(gameNotifierProvider.notifier).startCountdown(_pin!);

    // Host is the authority: move to the first question after 10s.
    _countdownTimer?.cancel();
    _countdownTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      ref.read(gameNotifierProvider.notifier).nextQuestion(_pin!, 0, durationSeconds: widget.quiz.questions.first.timeLimitSeconds,);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating || _pin == null) {
      return const Scaffold(
        backgroundColor: AppTheme.primary,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    final gameAsync = ref.watch(gameSessionProvider(_pin!));

    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final confirmed = await _confirmEnd();
          if (!confirmed) return;
          await ref.read(gameNotifierProvider.notifier).endGame(_pin!);
          if (mounted) context.go('/');
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
                child: Text('Session not found',
                    style: TextStyle(color: Colors.white))),
          );
        }

        // Countdown screen
        if (session.status == GameStatus.countdown) {
          return CountdownView(
            endsAt: session.countdownEndsAt ??
                DateTime.now().add(const Duration(seconds: 10)),
            title: 'Starting in...',
          );
        }

        // Route to correct screen based on status
        if (session.status == GameStatus.question) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/host-question/$_pin');
          });
        } else if (session.status == GameStatus.leaderboard) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/leaderboard/$_pin');
          });
        } else if (session.status == GameStatus.ended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/$_pin');
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
                final confirmed = await _confirmEnd();
                if (!confirmed) return;
                await ref.read(gameNotifierProvider.notifier).endGame(_pin!);
                if (mounted) context.go('/my-quizzes');
              },
            ),
            title: Text(widget.quiz.title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              TextButton(
                onPressed: () async {
                  final confirmed = await _confirmEnd();
                  if (!confirmed) return;
                  await ref.read(gameNotifierProvider.notifier).endGame(_pin!);
                  if (mounted) context.go('/');
                },
                child: const Text('End', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Text('Game PIN',
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _pin!,
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white54),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _pin!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN copied!')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Share this PIN with players',
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 20),

                // Players joined (now takes the remaining space)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${session.players.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Players Joined',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        Expanded(
                          child: session.players.isEmpty
                              ? const Center(
                            child: Text(
                              'Waiting for players to join...',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                              : SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children:
                              session.players.values.map((p) {
                                final displayName = p.name.trim().isEmpty
                                    ? 'Player'
                                    : p.name.trim();
                                return Chip(
                                  avatar: const Icon(Icons.person,
                                      size: 18, color: Colors.black54),
                                  label: Text(displayName),
                                  backgroundColor: AppTheme.accent,
                                  labelStyle: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Start button
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    onPressed: _startGame,
                    verticalPadding: 18,
                    child: const Text('Start Game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),

                ),
              ],
            ),
          ),
        );
      },
        ),
    );
  }
}

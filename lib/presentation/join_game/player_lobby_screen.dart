import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_session_model.dart';
import '../../data/services/game_provider.dart';
import '../game_play/countdown_view.dart';
import '../../core/widgets/back_guard.dart';

class PlayerLobbyScreen extends ConsumerWidget {
  final String pin;
  const PlayerLobbyScreen({super.key, required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameSessionProvider(pin));

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
                DateTime.now().add(const Duration(seconds: 10)),
            title: 'Get Ready!',
          );
        }

        // Navigate based on status
        if (session.status == GameStatus.question) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/player-question/$pin');
          });
        } else if (session.status == GameStatus.ended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/$pin');
          });
        }

        return Scaffold(
          backgroundColor: AppTheme.primary,
          appBar: AppBar(
            backgroundColor: AppTheme.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.go('/join-game'),
            ),
            title: const Text('Waiting for Host',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 64, color: AppTheme.accent),
                  const SizedBox(height: 24),
                  const Text(
                    'You\'re in!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Waiting for host to start...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  Container(
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
                              fontSize: 48,
                              fontWeight: FontWeight.bold),
                        ),
                        const Text('Players Joined',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
        ),
    );
  }
}

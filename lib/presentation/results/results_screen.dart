import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/game_provider.dart';

class ResultsScreen extends ConsumerWidget {
  final String pin;
  const ResultsScreen({super.key, required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameSessionProvider(pin));

    return gameAsync.when(
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
          return Scaffold(
            backgroundColor: AppTheme.primary,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Game Over!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    // ✅ Fixed: /home → /
                    onPressed: () => context.go('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
          );
        }

        final sorted = session.players.values.toList()
          ..sort((a, b) => b.score.compareTo(a.score));

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(                               // ✅ add this
            backgroundColor: AppTheme.primary,
            automaticallyImplyLeading: false,
            title: const Text('Final Results',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('🏆 Final Results',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${session.players.length} players',
                      style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),

                  if (sorted.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (sorted.length > 1)
                            _podiumItem(sorted[1].name, sorted[1].score,
                                2, 80, Colors.grey),
                          _podiumItem(sorted[0].name, sorted[0].score, 1,
                              110, AppTheme.accent),
                          if (sorted.length > 2)
                            _podiumItem(sorted[2].name, sorted[2].score,
                                3, 60, Colors.brown),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final player = sorted[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text('${index + 1}.',
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(player.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Text('${player.score} pts',
                                  style: const TextStyle(
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // ✅ Fixed: /home → /
                      onPressed: () => context.go('/'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.black,
                        padding:
                        const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back to Home',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _podiumItem(
      String name, int score, int rank, double height, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            rank == 1 ? '👑' : rank == 2 ? '🥈' : '🥉',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
          Text('$score pts',
              style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border.all(color: color),
            ),
            child: Center(
              child: Text('$rank',
                  style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
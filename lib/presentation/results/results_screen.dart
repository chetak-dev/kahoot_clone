import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/game_provider.dart';
import '../../core/utils/nav_helpers.dart';
import '../../data/services/auth_provider.dart';
import '../../core/widgets/gradient_button.dart';



class ResultsScreen extends ConsumerWidget {
  final String pin;
  const ResultsScreen({super.key, required this.pin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameSessionProvider(pin));
    final isHost = ref.watch(authNotifierProvider).valueOrNull?.isHost ?? false;

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
                  // "Back to Home" (empty state)
                  GradientButton(
                    onPressed: () => goHome(context, ref),
                    child: const Text('Back to Home'),
                  ),

                ],
              ),
            ),
          );
        }

        final sorted = session.players.values.toList()
          ..sort((a, b) {
            final scoreDiff = b.score.compareTo(a.score);
            if (scoreDiff != 0) return scoreDiff;
            return a.totalResponseTimeMs.compareTo(b.totalResponseTimeMs);
          });

        // Count shared scores so we surface the response-time tiebreaker only
        // when it's actually relevant (or always, for the host).
        final scoreCounts = <int, int>{};
        for (final p in sorted) {
          scoreCounts[p.score] = (scoreCounts[p.score] ?? 0) + 1;
        }




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
                        final isTied =
                            (scoreCounts[player.score] ?? 0) > 1;
                        final responseSeconds =
                        (player.totalResponseTimeMs / 1000)
                            .toStringAsFixed(1);
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${player.score} pts',
                                      style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontWeight: FontWeight.bold)),
                                  // Show the response-time tiebreaker for tied
                                  // scores — and always for the host.
                                  if (isTied || isHost)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.bolt_rounded,
                                              size: 12,
                                              color: Colors.white54),
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

                  Row(
                    children: [
                      if (!isHost) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go('/review/$pin'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Review answers'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: // "Home" (inside Expanded)
                        GradientButton(
                          onPressed: isHost
                              ? () => goHome(context, ref)
                              : () => _confirmExitHome(context, ref),
                          verticalPadding: 16,
                          child: const Text('Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),

                      ),
                    ],
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


  // Participants have no way back to this screen once they leave, so confirm
// before exiting to home.
  Future<void> _confirmExitHome(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Are you sure to exit?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "You won't be able to see this page again.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) goHome(context, ref);
  }


}
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/game_result_model.dart';

/// Read-only podium view of a saved game result — the same podium + ranking
/// layout players see at the end of a live quiz.
class ResultDetailScreen extends StatelessWidget {
  final GameResultModel result;
  const ResultDetailScreen({super.key, required this.result});

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    // Entries are stored high -> low, but sort defensively just in case.
    final sorted = [...result.entries]
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(result.quizTitle,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
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
              Text(
                '${result.playerCount} players  •  ${_formatDate(result.playedAt)}',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              if (sorted.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (sorted.length > 1)
                        _podiumItem(sorted[1].name, sorted[1].score, 2, 80,
                            Colors.grey),
                      _podiumItem(sorted[0].name, sorted[0].score, 1, 110,
                          AppTheme.accent),
                      if (sorted.length > 2)
                        _podiumItem(sorted[2].name, sorted[2].score, 3, 60,
                            Colors.brown),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              Expanded(
                child: sorted.isEmpty
                    ? const Center(
                  child: Text('No players',
                      style: TextStyle(color: Colors.white54)),
                )
                    : ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final entry = sorted[index];
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
                                  color: Colors.white54, fontSize: 16)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(entry.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Text('${entry.score} pts',
                              style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _podiumItem(
      String name, int score, int rank, double height, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            rank == 1
                ? '👑'
                : rank == 2
                ? '🥈'
                : '🥉',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 80,
            child: Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
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

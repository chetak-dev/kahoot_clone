import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/services/game_provider.dart';

class GameHistoryScreen extends ConsumerWidget {
  const GameHistoryScreen({super.key});

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(gameResultsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Past Results',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: resultsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white))),
        data: (results) {
          if (results.isEmpty) {
            return const Center(
              child: Text('No saved results yet.',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            );
          }
          final sorted = [...results]
            ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final r = sorted[index];
              final winner = r.entries.isNotEmpty ? r.entries.first : null;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  onTap: () => context.push('/result-detail', extra: r),
                  title: Text(r.quizTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${_formatDate(r.playedAt)}  •  ${r.playerCount} players'
                        '${winner != null ? '  •  🥇 ${winner.name}' : ''}',
                    style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppTheme.background,
                              title: const Text('Delete result',
                                  style: TextStyle(color: Colors.white)),
                              content: Text(
                                  'Delete the saved result for "${r.quizTitle}"?',
                                  style:
                                  const TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel',
                                        style:
                                        TextStyle(color: Colors.white54))),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete',
                                        style:
                                        TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await GameRepository().deleteSavedResult(r);
                          }

                        },
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white38),
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

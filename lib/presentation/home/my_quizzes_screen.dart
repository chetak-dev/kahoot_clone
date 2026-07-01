import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/quiz_model.dart';
import '../../data/repositories/quiz_repository.dart';
import '../../data/services/auth_provider.dart';
import '../../data/services/quiz_provider.dart';
import '../../core/widgets/gradient_button.dart';

class MyQuizzesScreen extends ConsumerWidget {
  /// True when shown as its own route (e.g. from "Host a Game"), false when
  /// embedded as a tab inside HomeScreen.
  final bool isStandalone;
  const MyQuizzesScreen({super.key, this.isStandalone = false});

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(myQuizzesProvider);

    final scaffold = Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        leading: isStandalone
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to home',
          onPressed: () => _goBack(context),
        )
            : null,
        title: const Text('My Quizzes',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [


        ],
      ),
      body: quizzesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white))),
        data: (quizzes) {
          if (quizzes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.quiz_outlined,
                      size: 64, color: Colors.white30),
                  const SizedBox(height: 16),
                  const Text('No quizzes yet',
                      style:
                      TextStyle(color: Colors.white54, fontSize: 18)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/create-quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Your First Quiz',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              return _QuizCard(quiz: quiz);
            },
          );
        },
      ),
    );

    // Only intercept the Android back button when shown as its own route.
    if (!isStandalone) return scaffold;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _goBack(context);
      },
      child: scaffold,
    );
  }
}

class _QuizCard extends ConsumerWidget {
  final QuizModel quiz;
  const _QuizCard({required this.quiz});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header (tap to view all questions)
          InkWell(
            onTap: () => context.push('/quiz-detail', extra: quiz),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.quiz_rounded,
                      color: AppTheme.accent, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(quiz.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '${quiz.questions.length} question${quiz.questions.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: // the "Host" button (inside Expanded)
                  GradientButton(
                    onPressed: quiz.questions.isEmpty ? null : () => context.go('/host-game', extra: quiz),
                    icon: Icons.play_arrow,
                    verticalPadding: 12,
                    borderRadius: 8,
                    child: const Text('Host', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),

                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.background,
                        title: const Text('Delete Quiz',
                            style: TextStyle(color: Colors.white)),
                        content: Text(
                            'Delete "${quiz.title}"? This cannot be undone.',
                            style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await QuizRepository().deleteQuiz(quiz.id);
                      ref.invalidate(myQuizzesProvider);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

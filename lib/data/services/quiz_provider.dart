// lib/data/services/quiz_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/question_model.dart';
import '../models/quiz_model.dart';
import '../repositories/quiz_repository.dart';
import 'auth_provider.dart';

// ── Quiz Editor State ──────────────────────────────────────────────────────────
// Holds the list of questions being built for a new quiz

class QuizEditorNotifier extends StateNotifier<List<QuestionModel>> {
  QuizEditorNotifier() : super([]);

  void addQuestion(QuestionModel question) {
    state = [...state, question];
  }

  void updateQuestion(int index, QuestionModel updated) {
    final list = [...state];
    list[index] = updated;
    state = list;
  }

  void removeQuestion(int index) {
    final list = [...state];
    list.removeAt(index);
    state = list;
  }

  void reorderQuestions(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
  }

  void clearAll() {
    state = [];
  }

  void setQuestions(List<QuestionModel> questions) {
    state = [...questions];
  }

}

final quizEditorProvider =
StateNotifierProvider<QuizEditorNotifier, List<QuestionModel>>(
      (ref) => QuizEditorNotifier(),
);

final myQuizzesProvider = StreamProvider<List<QuizModel>>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return QuizRepository().watchMyQuizzes(uid);
});
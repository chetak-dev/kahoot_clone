import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_session_model.dart';
import '../models/quiz_model.dart';
import '../repositories/game_repository.dart';
import 'auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_result_model.dart';


final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository();
});

final gameSessionProvider =
StreamProvider.family<GameSessionModel?, String>((ref, pin) {
  final repo = ref.read(gameRepositoryProvider);
  return repo.watchGame(pin);
});

final activePinProvider = StateProvider<String?>((ref) => null);

final gameNotifierProvider =
AsyncNotifierProvider<GameNotifier, void>(() => GameNotifier());

class GameNotifier extends AsyncNotifier<void> {
  late GameRepository _repo;

  @override
  Future<void> build() async {
    _repo = ref.read(gameRepositoryProvider);
  }

  // Host creates game
  Future<String> createGame(QuizModel quiz) async {
    final user = await ref.read(authNotifierProvider.future);
    if (user == null) throw Exception('Not logged in');
    final pin = await _repo.createGame(user.uid, quiz);
    ref.read(activePinProvider.notifier).state = pin;
    return pin;
  }

  // Player joins game
  // Player joins game
  Future<bool> joinGame(String pin, String name) async {
    // Use Firebase Auth directly — no Firestore needed just to get a uid
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) throw Exception('Not logged in');

    final success = await _repo.joinGame(pin, firebaseUser.uid, name);
    if (success) {
      ref.read(activePinProvider.notifier).state = pin;
    }
    return success;
  }

  // Host: start game
  Future<void> startGame(String pin, {int? durationSeconds}) async {
    await _repo.nextQuestion(pin, 0, durationSeconds: durationSeconds);
  }

  // Host: next question
  Future<void> nextQuestion(String pin, int index,
      {int? durationSeconds}) async {
    await _repo.nextQuestion(pin, index, durationSeconds: durationSeconds);
  }


  // Host: show leaderboard
  Future<void> showLeaderboard(String pin) async {
    await _repo.showLeaderboard(pin); // now sets the 5s auto-advance timer
  }


  // Host: end game
  Future<void> endGame(String pin) async {
    await _repo.endGame(pin);
  }

  // Player: submit answer
  // Player: submit answer
  Future<void> submitAnswer(
      String pin, String questionId, String answerId, int points,
      int responseTimeMs) async {
    final user = await ref.read(authNotifierProvider.future);
    if (user == null) throw Exception('Not logged in');
    await _repo.submitAnswer(
        pin, user.uid, questionId, answerId, points, responseTimeMs);
  }


  // Host: start the 60-second countdown
  Future<void> startCountdown(String pin, {int seconds = 60}) async {
    await _repo.startCountdown(pin, seconds: seconds);
  }


}

final gameResultsProvider = StreamProvider<List<GameResultModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return GameRepository().watchGameResults(uid);
});

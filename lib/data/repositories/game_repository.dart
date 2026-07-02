import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_session_model.dart';
import '../models/quiz_model.dart';
import '../models/game_result_model.dart';


class GameRepository {
  // ✅ Fixed: explicit regional URL
  final _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://kahoot-clone-39e22-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
  final _firestore = FirebaseFirestore.instance;

  // Create a new game session
  Future<String> createGame(String hostId, QuizModel quiz) async {
    final pin = _generatePin();
    final session = GameSessionModel(
      gamePin: pin,
      hostId: hostId,
      quizId: quiz.id,
      status: GameStatus.lobby,
      currentQuestion: 0,
      players: {},
      createdAt: DateTime.now(),
    );
    await _db.ref('game_sessions/$pin').set(session.toMap());
    return pin;
  }

  // Join a game
  Future<bool> joinGame(String pin, String playerId, String name) async {
    final ref = _db.ref('game_sessions/$pin');
    final snapshot = await ref.get();
    if (!snapshot.exists) return false;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    // Allow joining while the game is still in the lobby OR during the
    // pre-game countdown. Once the first question starts (or later), joining
    // is no longer allowed.
    final status = data['status'];
    if (status != 'lobby' && status != 'countdown') return false;


    final player = PlayerSession(
      playerId: playerId,
      name: name,
      score: 0,
      answers: {},
    );
    await _db
        .ref('game_sessions/$pin/players/$playerId')
        .set(player.toMap());
    return true;
  }

  // Watch game session in real-time
  Stream<GameSessionModel?> watchGame(String pin) {
    return _db.ref('game_sessions/$pin').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data =
      Map<String, dynamic>.from(event.snapshot.value as Map);
      return GameSessionModel.fromMap(data);
    });
  }

  // Host: start game / next question
  Future<void> updateGameStatus(String pin, GameStatus status) async {
    await _db
        .ref('game_sessions/$pin/status')
        .set(status.name);
  }

  Future<void> nextQuestion(String pin, int questionIndex,
      {int? durationSeconds}) async {
    final updates = <String, dynamic>{
      'currentQuestion': questionIndex,
      'status': GameStatus.question.name,
      'questionStartAtMs': ServerValue.timestamp, // ← always write this
    };
    if (durationSeconds != null) {
      updates['questionDurationSeconds'] = durationSeconds;
    }
    await _db.ref('game_sessions/$pin').update(updates);
  }



  // Player: submit answer
  // Player: submit answer
  Future<void> submitAnswer(
      String pin,
      String playerId,
      String questionId,
      String answerId,
      int points,
      int responseTimeMs) async {
    await _db
        .ref('game_sessions/$pin/players/$playerId/answers/$questionId')
        .set(answerId);
    await _db
        .ref('game_sessions/$pin/players/$playerId/score')
        .set(ServerValue.increment(points));
    // Always track response time — used as tiebreaker (lower = faster = better)
    await _db
        .ref('game_sessions/$pin/players/$playerId/totalResponseTimeMs')
        .set(ServerValue.increment(responseTimeMs));
  }


  // End game
  Future<void> endGame(String pin) async {
    await _db
        .ref('game_sessions/$pin/status')
        .set(GameStatus.ended.name);
  }

  // Delete game session
  Future<void> deleteGame(String pin) async {
    await _db.ref('game_sessions/$pin').remove();
  }

  // Get quiz for a game
  Future<QuizModel?> getQuizForGame(String quizId) async {
    final doc =
    await _firestore.collection('quizzes').doc(quizId).get();
    if (!doc.exists) return null;
    return QuizModel.fromMap(doc.data()!);
  }

  String _generatePin() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now % 900000 + 100000).toString();
  }

  // Host: begin a synced countdown before the first question
  Future<void> startCountdown(String pin, {int seconds = 60}) async {
    final endsAt = DateTime.now().add(Duration(seconds: seconds));
    await _db.ref('game_sessions/$pin').update({
      'status': GameStatus.countdown.name,
      'countdownEndsAt': endsAt.toIso8601String(),
    });
  }

  // Host: show leaderboard with a synced auto-advance countdown
  Future<void> showLeaderboard(String pin, {int seconds = 8}) async {
    final endsAt = DateTime.now().add(Duration(seconds: seconds));
    await _db.ref('game_sessions/$pin').update({
      'status': GameStatus.leaderboard.name,
      'countdownEndsAt': endsAt.toIso8601String(),
    });
  }

  // ── Saved game results (host history) ───────────────────────────────────────
  Future<void> saveGameResult(GameResultModel result) async {
    await _firestore
        .collection('game_results')
        .doc(result.id)
        .set(result.toMap());
  }

  Stream<List<GameResultModel>> watchGameResults(String hostId) {
    return _firestore
        .collection('game_results')
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .map((s) =>
        s.docs.map((d) => GameResultModel.fromMap(d.data())).toList());
  }

  Future<void> deleteGameResult(String id) async {
    await _firestore.collection('game_results').doc(id).delete();
  }

  // Difference (ms) between this device's clock and Firebase's server clock.
  // Difference (ms) between this device's clock and Firebase's server clock.
  // Difference (ms) between this device's clock and Firebase's server clock.
  Future<int> getServerTimeOffset() async {
    // NOTE: `.info/serverTimeOffset` is a synthetic client-side node.
    // Calling `.get()` on it is unreliable (it can hang or throw), so read it
    // via a one-shot listener instead, with a short timeout fallback.
    try {
      final event = await _db
          .ref('.info/serverTimeOffset')
          .onValue
          .first
          .timeout(const Duration(seconds: 2));
      final v = event.snapshot.value;
      if (v is num) return v.toInt();
    } catch (_) {
      // Fall through to 0 — a missing offset just means we trust local time.
    }
    return 0;
  }



  Stream<int> watchServerTimeOffset() {
    return _db.ref('.info/serverTimeOffset').onValue.map((event) {
      final v = event.snapshot.value;
      return v is num ? v.toInt() : 0;
    });
  }




}
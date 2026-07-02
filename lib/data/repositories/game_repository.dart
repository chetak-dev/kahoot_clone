import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_session_model.dart';
import '../models/quiz_model.dart';
import '../models/game_result_model.dart';

class GameRepository {
  // ✓ Fixed: explicit regional URL
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
    // Allow joining at any point while the game is still going — lobby,
    // countdown, an active question, or the leaderboard between questions.
    // A mid-game joiner starts at 0 points and is synced into the current
    // state (they'll answer from the next question they catch, or the rest of
    // the current one if time remains). Joining is only blocked once the game
    // has fully ended.
    final status = data['status'];
    if (status == 'ended') return false;

    final playerRef = _db.ref('game_sessions/$pin/players/$playerId');
    final player = PlayerSession(
      playerId: playerId,
      name: name,
      score: 0,
      answers: {},
    );
    await playerRef.set(player.toMap());

    // Presence: if this client disconnects (tab closed / network lost), the
    // server removes this player from the game, so their name drops off the
    // leaderboard automatically. On rejoin a fresh entry is written — so a new
    // nickname replaces the old one instead of leaving a stale duplicate.
    await playerRef.onDisconnect().remove();

    return true;
  }

  // Player intentionally leaves the game: remove them right away and cancel the
  // pending onDisconnect handler (no longer needed once they're gone).
  Future<void> leaveGame(String pin, String playerId) async {
    final playerRef = _db.ref('game_sessions/$pin/players/$playerId');
    await playerRef.onDisconnect().cancel();
    await playerRef.remove();
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

  // Reconcile results for a host who may have been absent when their game(s)
  // ended (e.g. dropped off during the game, which now auto-advances to the
  // end without them). For every ended session hosted by this host that has
  // no saved result yet, build and save the result so it shows up in history.
  //
  // Idempotent: a game is considered already-saved if a result whose id starts
  // with "<gamePin>_" exists, so re-running this never creates duplicates.
  Future<void> reconcileEndedHostResults(String hostId) async {
    final snapshot = await _db
        .ref('game_sessions')
        .orderByChild('hostId')
        .equalTo(hostId)
        .get();
    if (!snapshot.exists) return;

    final endedSessions = Map<dynamic, dynamic>.from(snapshot.value as Map)
        .values
        .map((e) =>
        GameSessionModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((s) =>
    s.status == GameStatus.ended && s.players.isNotEmpty)
        .toList();
    if (endedSessions.isEmpty) return;

    // Ids of results already saved for this host, to avoid duplicates.
    final existing = await _firestore
        .collection('game_results')
        .where('hostId', isEqualTo: hostId)
        .get();
    final existingIds = existing.docs.map((d) => d.id).toSet();

    for (final session in endedSessions) {
      final alreadySaved =
      existingIds.any((id) => id.startsWith('${session.gamePin}_'));
      if (alreadySaved) continue;

      final quiz = await getQuizForGame(session.quizId);
      final sorted = session.players.values.toList()
        ..sort((a, b) {
          final scoreDiff = b.score.compareTo(a.score);
          if (scoreDiff != 0) return scoreDiff;
          // Tiebreaker: faster total response time ranks higher.
          return a.totalResponseTimeMs.compareTo(b.totalResponseTimeMs);
        });

      final result = GameResultModel(
        // Deterministic id (based on the session's creation time) so repeated
        // reconciles overwrite the same doc instead of creating duplicates.
        id: '${session.gamePin}_${session.createdAt.millisecondsSinceEpoch}',
        hostId: session.hostId,
        quizId: session.quizId,
        quizTitle: quiz?.title ?? 'Quiz',
        playedAt: session.createdAt,
        playerCount: sorted.length,
        entries: sorted
            .map((p) => ResultEntry(name: p.name, score: p.score))
            .toList(),
      );
      await saveGameResult(result);
    }
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

  // Permanently delete a saved result AND its underlying game session, so the
  // host-return reconcile can never recreate it. Result ids are of the form
  // "<gamePin>_<timestamp>", so the PIN is the part before the first "_".
  //
  // The session is only removed if it is actually an ended game — this guards
  // against the rare case where the same PIN has since been reused by a new,
  // still-running game (deleting that would break a live session).
  Future<void> deleteSavedResult(GameResultModel result) async {
    await deleteGameResult(result.id);

    final pin = result.id.split('_').first;
    if (pin.isEmpty) return;

    final snapshot = await _db.ref('game_sessions/$pin').get();
    if (!snapshot.exists) return;
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    if (data['status'] == 'ended') {
      await deleteGame(pin);
    }
  }

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

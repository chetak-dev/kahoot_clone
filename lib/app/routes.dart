// lib/app/routes.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/services/auth_provider.dart';
import '../data/models/quiz_model.dart';
import '../presentation/auth/login_screen.dart';
import '../presentation/auth/signup_screen.dart';
import '../presentation/home/home_screen.dart';
import '../presentation/home/my_quizzes_screen.dart';
import '../presentation/home/quiz_detail_screen.dart';
import '../presentation/create_quiz/create_quiz_screen.dart';
import '../presentation/join_game/join_game_screen.dart';
import '../presentation/join_game/player_lobby_screen.dart';
import '../presentation/host_game/host_game_screen.dart';
import '../presentation/host_game/host_question_screen.dart';
import '../presentation/game_play/player_question_screen.dart';
import '../presentation/leaderboard/leaderboard_screen.dart';
import '../presentation/results/results_screen.dart';
import '../presentation/create_quiz/add_question_screen.dart';
import '../data/models/question_model.dart';
import '../presentation/home/game_history_screen.dart';
import '../presentation/home/result_detail_screen.dart';
import '../data/models/game_result_model.dart';
import '../presentation/auth/host_login_screen.dart';
import '../presentation/results/answer_review_screen.dart';

class _AuthNotifierListener extends ChangeNotifier {
  _AuthNotifierListener(this._ref) {
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final listener = _AuthNotifierListener(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: listener,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);

      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isHost = user?.isHost ?? false;

      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' ||
          location == '/signup' ||
          location == '/host-login';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        // Real users go to their dashboard. Guests may stay on the '/login'
        // landing — it's their home — so the system/browser back button can
        // return here instead of bouncing (which made a single back tap look
        // like it did nothing on web) or landing on the empty guest home.
        return (user?.isGuest ?? false) ? null : '/';
      }

      final hostOnlyRoutes = [
        '/create-quiz',
        '/my-quizzes',
        '/host-game',
        '/host-question',
        '/quiz-detail',
        '/edit-quiz',
        '/game-history',
      ];
      final isHostRoute = hostOnlyRoutes.any((r) => location.startsWith(r));
      if (isHostRoute && !isHost) return '/';

      return null;
    },
    routes: [
      // ── Auth ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),

      GoRoute(
        path: '/host-login',
        builder: (context, state) => const HostLoginScreen(),
      ),

      // ── Home ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),

      // ── My Quizzes ────────────────────────────────────────────────────────
      GoRoute(
        path: '/my-quizzes',
        builder: (context, state) => const MyQuizzesScreen(isStandalone: true),
      ),

      // ── Quiz Detail (view all questions) ──────────────────────────────────
      GoRoute(
        path: '/quiz-detail',
        builder: (context, state) {
          final quiz = state.extra as QuizModel;
          return QuizDetailScreen(quiz: quiz);
        },
      ),

      // ── Create Quiz ───────────────────────────────────────────────────────
      GoRoute(
        path: '/create-quiz',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final importCsv = extra?['importCsv'] == true;
          return CreateQuizScreen(importCsvOnOpen: importCsv);
        },
      ),

      // ── Edit Quiz ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/edit-quiz',
        builder: (context, state) {
          final quiz = state.extra as QuizModel;
          return CreateQuizScreen(quizToEdit: quiz);
        },
      ),

      GoRoute(
        path: '/game-history',
        builder: (context, state) => const GameHistoryScreen(),
      ),

      GoRoute(
        path: '/result-detail',
        builder: (context, state) {
          final result = state.extra as GameResultModel;
          return ResultDetailScreen(result: result);
        },
      ),

      // ── Host Game (lobby — receives QuizModel) ────────────────────────────
      GoRoute(
        path: '/host-game',
        builder: (context, state) {
          final quiz = state.extra as QuizModel;
          return HostGameScreen(quiz: quiz);
        },
      ),

      // ── Host Question ─────────────────────────────────────────────────────
      GoRoute(
        path: '/host-question/:pin',
        builder: (context, state) {
          final pin = state.pathParameters['pin']!;
          return HostQuestionScreen(pin: pin);
        },
      ),

      // ── Player: Join + Lobby + Question ───────────────────────────────────
      GoRoute(
        path: '/join-game',
        builder: (context, state) => const JoinGameScreen(),
      ),
      GoRoute(
        path: '/player-lobby/:pin',
        builder: (context, state) {
          final pin = state.pathParameters['pin']!;
          return PlayerLobbyScreen(pin: pin);
        },
      ),
      GoRoute(
        path: '/player-question/:pin',
        builder: (context, state) {
          final pin = state.pathParameters['pin']!;
          return PlayerQuestionScreen(pin: pin);
        },
      ),

      // ── Leaderboard + Results ─────────────────────────────────────────────
      GoRoute(
        path: '/leaderboard/:pin',
        builder: (context, state) {
          final pin = state.pathParameters['pin']!;
          return LeaderboardScreen(pin: pin);
        },
      ),
      GoRoute(
        path: '/results/:pin',
        builder: (context, state) {
          final pin = state.pathParameters['pin']!;
          return ResultsScreen(pin: pin);
        },
      ),

      GoRoute(
        path: '/review/:pin',
        builder: (context, state) {
          final pin = state.pathParameters['pin']!;
          return AnswerReviewScreen(pin: pin);
        },
      ),

      GoRoute(
        path: '/add-question',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddQuestionScreen(
            questionToEdit: extra?['question'] as QuestionModel?,
            editIndex: extra?['index'] as int?,
          );
        },
      ),

    ],
  );
});

// lib/presentation/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_provider.dart';
import '../../data/services/game_provider.dart';
import '../home/my_quizzes_screen.dart';

final _selectedTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _lastBackPressed;

  void _handleBack() {
    // If on a sub-tab (e.g. My Quizzes), go back to the Home tab first.
    if (ref.read(_selectedTabProvider) != 0) {
      ref.read(_selectedTabProvider.notifier).state = 0;
      return;
    }
    // On the Home tab: require a second back press within 2 seconds to exit.
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      SystemNavigator.pop(); // exit the app
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
            const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(authNotifierProvider.notifier).signOut();
    }
  }

  Future<void> _goToHostSignIn() async {
    // End the anonymous guest session, otherwise the router's redirect
    // guard sends a logged-in user straight back to '/'.
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final isHost = ref.watch(isHostProvider);
    final selectedTab = ref.watch(_selectedTabProvider);

    final tabs = [
      _HomeTab(isHost: isHost, user: user, onHostSignIn: _goToHostSignIn),
      if (isHost) const MyQuizzesScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Icon(Icons.quiz_rounded, color: AppTheme.accent),
              const SizedBox(width: 8),
              const Text(
                'VOGI Quiz',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 8),
              if (isHost)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'HOST',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            if (!(user?.isGuest ?? false))
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Sign out',
                onPressed: _confirmSignOut,
              ),
          ],

        ),
        body: tabs[selectedTab.clamp(0, tabs.length - 1)],
        bottomNavigationBar: isHost
            ? BottomNavigationBar(
          currentIndex: selectedTab.clamp(0, tabs.length - 1),
          onTap: (i) =>
          ref.read(_selectedTabProvider.notifier).state = i,
          backgroundColor: AppTheme.primary,
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: Colors.white54,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.quiz_rounded),
              label: 'My Quizzes',
            ),
          ],
        )
            : null,
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  final bool isHost;
  final dynamic user;
  final VoidCallback onHostSignIn;

  const _HomeTab({
    required this.isHost,
    required this.user,
    required this.onHostSignIn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When a host opens their dashboard, quietly save results for any games
    // that ended while they were away, so they appear in Past Results.
    if (isHost) {
      ref.watch(hostResultsReconcileProvider);
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppTheme.accent.withOpacity(0.15),
              child: Icon(
                isHost
                    ? Icons.manage_accounts_rounded
                    : Icons.person_rounded,
                size: 52,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome, ${user?.displayName ?? 'Player'}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isHost ? 'Host Dashboard' : 'Ready to play?',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),
            if (isHost) ...[
              _ActionCard(
                icon: Icons.add_circle_outline_rounded,
                label: 'Create Quiz',
                subtitle: 'Build a new quiz from scratch',
                color: AppTheme.accent,
                onTap: () => context.go('/create-quiz'),
              ),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.play_circle_outline_rounded,
                label: 'Host a Game',
                subtitle: 'Start a live game session',
                color: Colors.greenAccent,
                onTap: () => context.push('/my-quizzes'),
              ),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.leaderboard_rounded,
                label: 'Past Results',
                subtitle: 'View and manage saved leaderboards',
                color: Colors.purpleAccent,
                onTap: () => context.push('/game-history'),
              ),

            ]

          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/presentation/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/services/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _joinAsGuest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signInAsGuest('Guest');
      if (mounted) context.go('/join-game'); // straight to Join a Game
    } catch (_) {
      setState(() => _error = 'Could not join. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable main content ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/logo.png', height: 150),
                        const SizedBox(height: 16),
                        const SizedBox(height: 58),
                        Text(
                          'Get Ready for a Multiplayer Live Quiz Game',
                          style:
                          TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                        ),
                        const SizedBox(height: 24),

                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.redAccent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                        color: Colors.redAccent, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Primary action: Join a Game ──────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: GradientButton(
                            onPressed: _isLoading ? null : _joinAsGuest,
                            verticalPadding: 18,
                            borderRadius: 14,
                            icon: _isLoading ? null : Icons.gamepad_rounded,
                            child: _isLoading
                                ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                                : const Text(
                              'Join a Game',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Secondary: small host sign-in link ───────────────
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.push('/host-login'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.6),
                          ),
                          child: const Text.rich(
                            TextSpan(
                              text: 'Are you a host? ',
                              children: [
                                TextSpan(
                                  text: 'Sign in',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Footer — always visible, never needs scrolling ───────────
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Made with ',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14)),
                  const Icon(Icons.favorite,
                      color: Colors.redAccent, size: 15),
                  Text(' by VOGI Team',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/game_provider.dart';
import '../../core/widgets/back_guard.dart';

class JoinGameScreen extends ConsumerStatefulWidget {
  const JoinGameScreen({super.key});

  @override
  ConsumerState<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends ConsumerState<JoinGameScreen> {
  final _pinController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _pinController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinGame() async {
    if (_pinController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit PIN')),
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your nickname')),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final success = await ref.read(gameNotifierProvider.notifier).joinGame(
        _pinController.text.trim(),
        _nameController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        context.go('/player-lobby/${_pinController.text.trim()}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game not found or already started!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackGuard(
        destination: '/',
        child: Scaffold(
          backgroundColor: AppTheme.primary,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Join Live Quiz',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.gamepad_rounded,
                          size: 80, color: Colors.white),
                      const SizedBox(height: 24),
                      const Text(
                        'Enter Quiz Code',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: const TextStyle(color: Colors.white24),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: AppTheme.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style:
                        const TextStyle(color: Colors.white, fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'Your Nickname',
                          hintStyle: const TextStyle(color: Colors.white38),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: AppTheme.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isJoining ? null : _joinGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isJoining
                            ? const CircularProgressIndicator(
                            color: Colors.black)
                            : const Text('Join Now!',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
        ),
    );
  }
}
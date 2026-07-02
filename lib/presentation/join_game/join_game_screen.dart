import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/game_provider.dart';
import '../../data/services/auth_provider.dart';
import '../../core/widgets/gradient_button.dart';

class JoinGameScreen extends ConsumerStatefulWidget {
  const JoinGameScreen({super.key});

  @override
  ConsumerState<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends ConsumerState<JoinGameScreen> {
  final _pinController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isJoining = false;
  bool _agreedToInstructions = false;
  bool _showCheckboxError = false;

  // ─────────────────────────────────────────────────────────────────────
  // EDIT YOUR INSTRUCTIONS HERE
  // ─────────────────────────────────────────────────────────────────────
  static const String _instructionsText = '''
1. Do not close or refresh the browser tab once the quiz has started.

2. Participants with the same score will be ranked based on who submits the answer first.

3. Tapping an option does NOT lock your answer. You must press "Submit Answer" to confirm.
''';
  // ─────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pinController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _leaveToHome() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go('/login');
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
    if (!_agreedToInstructions) {
      setState(() => _showCheckboxError = true);
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
          const SnackBar(content: Text('Game not found or already ended!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _leaveToHome();
      },

      child: Scaffold(
        backgroundColor: AppTheme.primary,
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _leaveToHome,
          ),
          title: const Text('Join Live Quiz',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Instructions card — flush to top, compact ────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.white.withOpacity(0.2)),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.info_outline,
                                  color: AppTheme.accent, size: 15),
                              SizedBox(width: 6),
                              Text(
                                'Instructions',
                                style: TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _instructionsText,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Form ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          // Enter Quiz Code heading
                          const Text(
                            'Enter Quiz Code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── PIN field — same height as nickname ───────
                          TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,       // ← matches nickname
                              fontWeight: FontWeight.bold,
                              letterSpacing: 10,  // spacing keeps it readable
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '0  0  0  0  0  0',
                              hintStyle:
                              const TextStyle(color: Colors.white24),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                const BorderSide(color: Colors.white30),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                const BorderSide(color: AppTheme.accent),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── Nickname field ────────────────────────────
                          TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                            onSubmitted: (_) => _joinGame(),
                            decoration: InputDecoration(
                              hintText: 'Your Nickname',
                              hintStyle:
                              const TextStyle(color: Colors.white38),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                const BorderSide(color: Colors.white30),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                const BorderSide(color: AppTheme.accent),
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // ── Mandatory checkbox ────────────────────────
                          Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: Colors.white38,
                            ),
                            child: CheckboxListTile(
                              value: _agreedToInstructions,
                              onChanged: (v) => setState(() {
                                _agreedToInstructions = v ?? false;
                                if (_agreedToInstructions) {
                                  _showCheckboxError = false;
                                }
                              }),
                              activeColor: AppTheme.accent,
                              checkColor: Colors.black,
                              controlAffinity:
                              ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'I have read the above Quiz instructions',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ),

                          // ── Error message just above button ───────────
                          if (_showCheckboxError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: const [
                                  Icon(Icons.error_outline,
                                      color: Colors.redAccent, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Please accept the instructions to proceed',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                          SizedBox(height: _showCheckboxError ? 4 : 16),

                          // ── Join button — always yellow ───────────────
                          GradientButton(
                            onPressed: _isJoining ? null : _joinGame,
                            child: _isJoining
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : const Text('Join Now!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

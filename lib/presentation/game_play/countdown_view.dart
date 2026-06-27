// lib/presentation/game_play/countdown_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CountdownView extends StatefulWidget {
  final DateTime endsAt;
  final String title;
  const CountdownView({
    super.key,
    required this.endsAt,
    this.title = 'Get Ready!',
  });

  @override
  State<CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends State<CountdownView> {
  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _calc();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _calc());
    });
  }

  int _calc() {
    final diff = widget.endsAt.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent,
              ),
              alignment: Alignment.center,
              child: Text(
                '$_remaining',
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 72,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'The quiz is about to begin',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

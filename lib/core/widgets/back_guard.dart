import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wraps [child] so the Android back button goes to [destination] (or pops if
/// possible) instead of closing the app.
class BackGuard extends StatelessWidget {
  final String destination;
  final Widget child;
  const BackGuard({super.key, required this.destination, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(destination);
        }
      },
      child: child,
    );
  }
}

// lib/core/utils/nav_helpers.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/auth_provider.dart';

/// Sends a user to their "home":
///  • Hosts  -> dashboard ('/')
///  • Guests -> signed out and back to the landing screen ('/login')
Future<void> goHome(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authNotifierProvider).valueOrNull;
  final isGuest = user?.isGuest ?? true;
  if (isGuest) {
    await ref.read(authNotifierProvider.notifier).signOut();
  }
  if (context.mounted) context.go(isGuest ? '/login' : '/');
}

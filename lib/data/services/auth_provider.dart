// lib/data/services/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// ── Auth state notifier ────────────────────────────────────────────────────────
class AuthNotifier extends AsyncNotifier<UserModel?> {

  @override
  Future<UserModel?> build() async {
    final completer = Completer<UserModel?>();

    FirebaseAuth.instance.authStateChanges().first.then((_) async {
      final user = await ref.read(authRepositoryProvider).getCurrentUser();
      completer.complete(user);
    });

    return completer.future;
  }

  Future<void> signUp(String email, String password, String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
          () => ref.read(authRepositoryProvider).signUp(email, password, displayName),
    );
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user =
      await ref.read(authRepositoryProvider).signIn(email, password);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow; // surface the error to the UI
    }
  }

  Future<void> signInAsGuest(String nickname) async {
    state = const AsyncLoading();
    try {
      final user =
      await ref.read(authRepositoryProvider).signInAsGuest(nickname);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }


  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);

// ── Convenience providers ──────────────────────────────────────────────────────
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authNotifierProvider).valueOrNull;
});

final isHostProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.isHost ?? false;
});

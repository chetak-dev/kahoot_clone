// lib/data/repositories/auth_repository.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

// ─── Hardcoded host credentials ───────────────────────────────────────────────
const String _kHostEmail = 'chetak526@gmail.com';
// ──────────────────────────────────────────────────────────────────────────────

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Determine role based on email
  String _resolveRole(String email) {
    return email.trim().toLowerCase() == _kHostEmail ? 'host' : 'player';
  }

  // ── Sign in ────────────────────────────────────────────────────────────────
  Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final firebaseUser = credential.user!;
    final role = _resolveRole(firebaseUser.email ?? '');

    final userModel = UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? 'User',
      photoUrl: firebaseUser.photoURL,
      isGuest: false,
      role: role,
    );

    // Persist role to Firestore so it's available elsewhere
    await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .set(userModel.toMap(), SetOptions(merge: true));

    return userModel;
  }

  // ── Sign up ────────────────────────────────────────────────────────────────
  Future<UserModel> signUp(String email, String password, String displayName) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final firebaseUser = credential.user!;
    await firebaseUser.updateDisplayName(displayName.trim());

    // New sign-ups are always players (host is hardcoded)
    final userModel = UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: displayName.trim(),
      isGuest: false,
      role: 'player',
    );

    await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .set(userModel.toMap());

    return userModel;
  }

  // ── Guest join ─────────────────────────────────────────────────────────────
  Future<UserModel> signInAsGuest(String nickname) async {
    final credential = await _auth.signInAnonymously();
    final firebaseUser = credential.user!;

    final userModel = UserModel(
      uid: firebaseUser.uid,
      email: '',
      displayName: nickname.trim(),
      isGuest: true,
      role: 'player',
    );

    await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .set(userModel.toMap());

    return userModel;
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Get current user from Firestore ───────────────────────────────────────
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    // For the host, always resolve role from email (not Firestore)
    final role = _resolveRole(firebaseUser.email ?? '');

    final doc = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      data['role'] = role; // always override with resolved role
      return UserModel.fromMap(data);
    }

    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? 'User',
      isGuest: firebaseUser.isAnonymous,
      role: role,
    );
  }

  // ── Auth state stream ──────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

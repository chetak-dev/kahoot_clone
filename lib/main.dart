import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Already initialized — safe to ignore
  }

  // Force a fresh login on every app launch: clear any persisted session so
  // the user must enter their credentials again after the app is closed.
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {
    // No session / sign-out failed — safe to ignore.
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

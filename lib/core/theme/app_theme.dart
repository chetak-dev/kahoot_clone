import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF46178F);    // Kahoot purple
  static const Color accent = Color(0xFFF5A623);     // ISKCON Brahmapur gold
  static const Color accentDark = Color(0xFFD98300);  // deeper gold (gradients/shadows)
  static const Color background = Color(0xFF2D0A6B); // Dark purple
  static const Color correct = Color(0xFF26890C);    // Green
  static const Color incorrect = Color(0xFFE63A19);  // Red

  // Metallic gold gradient inspired by the logo — vertical so buttons read
  // as an embossed 3D face (bright highlight on top, deep gold at the base).
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFD66B), Color(0xFFF5A623), Color(0xFFE08A00)],
    stops: [0.0, 0.55, 1.0],
  );
}

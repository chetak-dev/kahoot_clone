import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A raised, professional button filled with the logo's metallic gold
/// gradient.
///
/// Built on [ElevatedButton], so it keeps correct sizing (content-sized on
/// its own, full-width inside an [Expanded] or width-constrained box), label
/// centering, and a tactile press: it sits raised with a soft shadow and
/// visibly depresses when tapped. Disabled state is dimmed and flat.
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final double verticalPadding;
  final double horizontalPadding;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.verticalPadding = 16,
    this.horizontalPadding = 20,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(borderRadius);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        disabledForegroundColor: Colors.white60,
        // Solid gold gives the elevation shadow something to cast from;
        // the gradient Ink below paints over it.
        backgroundColor: AppTheme.accent,
        disabledBackgroundColor: Colors.white.withOpacity(0.12),
        shadowColor: Colors.black,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ).copyWith(
        // Raised at rest, lifts on hover, presses down on tap.
        elevation: MaterialStateProperty.resolveWith((states) {
          if (!enabled) return 0;
          if (states.contains(MaterialState.pressed)) return 2;
          if (states.contains(MaterialState.hovered)) return 8;
          return 6;
        }),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: enabled ? AppTheme.goldGradient : null,
          borderRadius: radius,
          border: enabled
              ? const Border(
            top: BorderSide(color: Color(0x55FFFFFF), width: 1),
          )
              : null,
        ),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: horizontalPadding,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: enabled ? Colors.black : Colors.white60,
              fontWeight: FontWeight.bold,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 22,
                      color: enabled ? Colors.black : Colors.white60),
                  const SizedBox(width: 8),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

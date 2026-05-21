import 'package:flutter/material.dart';

/// Animated focus ring shown at tap position.
///
/// Displays a shrinking circle animation when the user taps on the
/// camera preview to indicate the focus point.
class FocusIndicator extends StatelessWidget {
  /// Creates a [FocusIndicator] at the given [position].
  const FocusIndicator({
    required this.position,
    required this.animation,
    this.size = 72,
    this.color,
    super.key,
  });

  /// Center position of the focus indicator.
  final Offset position;

  /// Animation controller driving the ring animation.
  final AnimationController animation;

  /// Size of the focus ring.
  final double size;

  /// Color of the focus ring (defaults to white).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? Colors.white.withValues(alpha: 0.85);

    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final scale = 1.0 + 0.3 * (1.0 - animation.value);
          final opacity = (1.0 - animation.value * 0.5).clamp(0.0, 1.0);

          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

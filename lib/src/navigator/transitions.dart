import 'package:flutter/material.dart';

/// Signature for a page transition builder.
typedef PageTransitionBuilder =
    Widget Function(
      Widget child,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    );

/// Pre-built transition builders for common page transitions.
///
/// Example:
/// ```dart
/// StateMachinePage(
///   stateId: 'home',
///   child: HomeScreen(),
///   transitionBuilder: StateMachineTransitions.slideFromRight,
/// )
/// ```
abstract class StateMachineTransitions {
  /// Fade transition.
  static Widget fade(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }

  /// Slide from right transition (iOS-style push).
  static Widget slideFromRight(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }

  /// Slide from left transition.
  static Widget slideFromLeft(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }

  /// Slide from bottom transition (modal-style).
  static Widget slideFromBottom(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }

  /// Slide from top transition.
  static Widget slideFromTop(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, -1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }

  /// Scale transition with fade.
  static Widget scale(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Zoom in transition (Android-style).
  static Widget zoom(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.85,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Shared axis horizontal transition (Material 3 style).
  static Widget sharedAxisHorizontal(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.3, 0.0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }

  /// Shared axis vertical transition (Material 3 style).
  static Widget sharedAxisVertical(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }

  /// No transition (instant).
  static Widget none(
    Widget child,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => child;

  /// Create a custom slide transition.
  static PageTransitionBuilder slide({
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    return (child, animation, secondaryAnimation) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: begin,
          end: end,
        ).animate(CurvedAnimation(parent: animation, curve: curve)),
        child: child,
      );
    };
  }

  /// Create a custom fade transition with curve.
  static PageTransitionBuilder fadeCurved({Curve curve = Curves.easeInOut}) {
    return (child, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: curve),
        child: child,
      );
    };
  }

  /// Combine multiple transitions.
  static PageTransitionBuilder combine(List<PageTransitionBuilder> builders) {
    return (child, animation, secondaryAnimation) {
      Widget result = child;
      for (final builder in builders.reversed) {
        result = builder(result, animation, secondaryAnimation);
      }
      return result;
    };
  }
}

import 'package:flutter/material.dart';

import 'transitions.dart';

/// A Page that supports custom transitions for state machine navigation.
///
/// Example:
/// ```dart
/// StateMachinePage(
///   key: ValueKey('login'),
///   stateId: 'loggedOut',
///   child: LoginScreen(),
///   transitionBuilder: StateMachineTransitions.slideFromRight,
///   transitionDuration: Duration(milliseconds: 400),
/// )
/// ```
class StateMachinePage<T> extends Page<T> {
  /// The state ID this page represents.
  final String stateId;

  /// The widget to display.
  final Widget child;

  /// Custom transition builder for this page.
  /// If null, uses the platform default transition.
  final PageTransitionBuilder? transitionBuilder;

  /// Duration for the enter transition.
  final Duration transitionDuration;

  /// Duration for the reverse (exit) transition.
  final Duration reverseTransitionDuration;

  /// Whether this page maintains state when not visible.
  final bool maintainState;

  /// Whether this page is opaque (covers pages behind it).
  final bool opaque;

  /// Whether this page should be presented as a fullscreen dialog.
  final bool fullscreenDialog;

  /// Barrier color for modal routes.
  final Color? barrierColor;

  /// Barrier label for accessibility.
  final String? barrierLabel;

  /// Whether the barrier is dismissible (for modal routes).
  final bool barrierDismissible;

  /// Creates a state machine page.
  const StateMachinePage({
    required this.stateId,
    required this.child,
    this.transitionBuilder,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration = const Duration(milliseconds: 300),
    this.maintainState = true,
    this.opaque = true,
    this.fullscreenDialog = false,
    this.barrierColor,
    this.barrierLabel,
    this.barrierDismissible = false,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return StateMachinePageRoute<T>(page: this);
  }

  /// Create a page with fade transition.
  factory StateMachinePage.fade({
    required String stateId,
    required Widget child,
    LocalKey? key,
    String? name,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) {
    return StateMachinePage(
      key: key,
      name: name,
      stateId: stateId,
      child: child,
      transitionBuilder: StateMachineTransitions.fade,
      transitionDuration: transitionDuration,
    );
  }

  /// Create a page with slide from right transition.
  factory StateMachinePage.slideFromRight({
    required String stateId,
    required Widget child,
    LocalKey? key,
    String? name,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) {
    return StateMachinePage(
      key: key,
      name: name,
      stateId: stateId,
      child: child,
      transitionBuilder: StateMachineTransitions.slideFromRight,
      transitionDuration: transitionDuration,
    );
  }

  /// Create a page with slide from bottom transition (modal style).
  factory StateMachinePage.modal({
    required String stateId,
    required Widget child,
    LocalKey? key,
    String? name,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) {
    return StateMachinePage(
      key: key,
      name: name,
      stateId: stateId,
      child: child,
      transitionBuilder: StateMachineTransitions.slideFromBottom,
      transitionDuration: transitionDuration,
      fullscreenDialog: true,
    );
  }

  /// Create a page with no transition (instant).
  factory StateMachinePage.instant({
    required String stateId,
    required Widget child,
    LocalKey? key,
    String? name,
  }) {
    return StateMachinePage(
      key: key,
      name: name,
      stateId: stateId,
      child: child,
      transitionBuilder: StateMachineTransitions.none,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}

/// Route implementation for [StateMachinePage] with custom transitions.
class StateMachinePageRoute<T> extends PageRoute<T> {
  /// The page configuration.
  final StateMachinePage<T> page;

  /// Creates a route for a state machine page.
  StateMachinePageRoute({required this.page}) : super(settings: page);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return page.child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (page.transitionBuilder != null) {
      return page.transitionBuilder!(child, animation, secondaryAnimation);
    }

    // Use platform default transition
    final theme = Theme.of(context);
    return theme.pageTransitionsTheme.buildTransitions<T>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }

  @override
  Duration get transitionDuration => page.transitionDuration;

  @override
  Duration get reverseTransitionDuration => page.reverseTransitionDuration;

  @override
  bool get maintainState => page.maintainState;

  @override
  bool get opaque => page.opaque;

  @override
  bool get fullscreenDialog => page.fullscreenDialog;

  @override
  Color? get barrierColor => page.barrierColor;

  @override
  String? get barrierLabel => page.barrierLabel;

  @override
  bool get barrierDismissible => page.barrierDismissible;
}

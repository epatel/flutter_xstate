import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/state_machine_actor.dart';
import '../events/x_event.dart';

/// A redirect function type for go_router.
///
/// This is an alias for go_router's redirect function signature.
typedef StateRedirectFunction = String? Function(BuildContext context, GoRouterState state);

/// Creates a redirect function that checks if the state machine matches a state.
///
/// Returns [redirectTo] if the state machine is in [stateId], otherwise returns null.
///
/// Example:
/// ```dart
/// GoRouter(
///   redirect: redirectWhenMatches(
///     authActor,
///     stateId: 'unauthenticated',
///     redirectTo: '/login',
///   ),
///   routes: [...],
/// )
/// ```
StateRedirectFunction redirectWhenMatches<TContext, TEvent extends XEvent>(
  StateMachineActor<TContext, TEvent> actor, {
  required String stateId,
  required String redirectTo,
  List<String>? exceptPaths,
}) {
  return (context, state) {
    if (exceptPaths != null) {
      for (final path in exceptPaths) {
        if (state.matchedLocation.startsWith(path)) {
          return null;
        }
      }
    }

    if (actor.matches(stateId)) {
      return redirectTo;
    }
    return null;
  };
}

/// Creates a redirect function that checks if the state machine does NOT match a state.
///
/// Returns [redirectTo] if the state machine is NOT in [stateId], otherwise returns null.
///
/// Example:
/// ```dart
/// GoRouter(
///   redirect: redirectWhenNotMatches(
///     authActor,
///     stateId: 'authenticated',
///     redirectTo: '/login',
///   ),
///   routes: [...],
/// )
/// ```
StateRedirectFunction redirectWhenNotMatches<TContext, TEvent extends XEvent>(
  StateMachineActor<TContext, TEvent> actor, {
  required String stateId,
  required String redirectTo,
  List<String>? exceptPaths,
}) {
  return (context, state) {
    if (exceptPaths != null) {
      for (final path in exceptPaths) {
        if (state.matchedLocation.startsWith(path)) {
          return null;
        }
      }
    }

    if (!actor.matches(stateId)) {
      return redirectTo;
    }
    return null;
  };
}

/// Creates a redirect function based on a context condition.
///
/// Returns [redirectTo] if [condition] returns true for the current context.
///
/// Example:
/// ```dart
/// GoRouter(
///   redirect: redirectWhenContext(
///     authActor,
///     condition: (ctx) => !ctx.isEmailVerified,
///     redirectTo: '/verify-email',
///   ),
///   routes: [...],
/// )
/// ```
StateRedirectFunction redirectWhenContext<TContext, TEvent extends XEvent>(
  StateMachineActor<TContext, TEvent> actor, {
  required bool Function(TContext context) condition,
  required String redirectTo,
  List<String>? exceptPaths,
}) {
  return (context, state) {
    if (exceptPaths != null) {
      for (final path in exceptPaths) {
        if (state.matchedLocation.startsWith(path)) {
          return null;
        }
      }
    }

    if (condition(actor.snapshot.context)) {
      return redirectTo;
    }
    return null;
  };
}

/// Combines multiple redirect functions into one.
///
/// Redirects are evaluated in order, and the first non-null result is returned.
///
/// Example:
/// ```dart
/// GoRouter(
///   redirect: combineRedirects([
///     redirectWhenNotMatches(authActor, stateId: 'authenticated', redirectTo: '/login'),
///     redirectWhenContext(profileActor, condition: (ctx) => !ctx.isComplete, redirectTo: '/setup'),
///   ]),
///   routes: [...],
/// )
/// ```
StateRedirectFunction combineRedirects(List<StateRedirectFunction> redirects) {
  return (context, state) {
    for (final redirect in redirects) {
      final result = redirect(context, state);
      if (result != null) {
        return result;
      }
    }
    return null;
  };
}

/// A builder class for creating complex redirect logic.
///
/// Example:
/// ```dart
/// final redirect = RedirectBuilder<AuthContext, AuthEvent>(authActor)
///   .whenMatches('unauthenticated', redirectTo: '/login')
///   .whenMatches('unverified', redirectTo: '/verify')
///   .whenContext((ctx) => ctx.isSuspended, redirectTo: '/suspended')
///   .exceptPaths(['/legal', '/support'])
///   .build();
///
/// GoRouter(
///   redirect: redirect,
///   routes: [...],
/// )
/// ```
class RedirectBuilder<TContext, TEvent extends XEvent> {
  final StateMachineActor<TContext, TEvent> _actor;
  final List<_RedirectRule<TContext>> _rules = [];
  final List<String> _exceptPaths = [];

  RedirectBuilder(this._actor);

  /// Add a redirect rule for when the state matches.
  RedirectBuilder<TContext, TEvent> whenMatches(
    String stateId, {
    required String redirectTo,
  }) {
    _rules.add(_RedirectRule(
      type: _RedirectRuleType.matches,
      stateId: stateId,
      redirectTo: redirectTo,
    ));
    return this;
  }

  /// Add a redirect rule for when the state does not match.
  RedirectBuilder<TContext, TEvent> whenNotMatches(
    String stateId, {
    required String redirectTo,
  }) {
    _rules.add(_RedirectRule(
      type: _RedirectRuleType.notMatches,
      stateId: stateId,
      redirectTo: redirectTo,
    ));
    return this;
  }

  /// Add a redirect rule based on a context condition.
  RedirectBuilder<TContext, TEvent> whenContext(
    bool Function(TContext context) condition, {
    required String redirectTo,
  }) {
    _rules.add(_RedirectRule(
      type: _RedirectRuleType.context,
      condition: condition,
      redirectTo: redirectTo,
    ));
    return this;
  }

  /// Add paths that should be excluded from all redirects.
  RedirectBuilder<TContext, TEvent> exceptPaths(List<String> paths) {
    _exceptPaths.addAll(paths);
    return this;
  }

  /// Build the redirect function.
  StateRedirectFunction build() {
    return (context, state) {
      // Check if path is excluded
      for (final path in _exceptPaths) {
        if (state.matchedLocation.startsWith(path)) {
          return null;
        }
      }

      // Evaluate rules in order
      for (final rule in _rules) {
        final result = _evaluateRule(rule);
        if (result != null) {
          return result;
        }
      }

      return null;
    };
  }

  String? _evaluateRule(_RedirectRule<TContext> rule) {
    switch (rule.type) {
      case _RedirectRuleType.matches:
        if (_actor.matches(rule.stateId!)) {
          return rule.redirectTo;
        }
        break;
      case _RedirectRuleType.notMatches:
        if (!_actor.matches(rule.stateId!)) {
          return rule.redirectTo;
        }
        break;
      case _RedirectRuleType.context:
        if (rule.condition!(_actor.snapshot.context)) {
          return rule.redirectTo;
        }
        break;
    }
    return null;
  }
}

enum _RedirectRuleType { matches, notMatches, context }

class _RedirectRule<TContext> {
  final _RedirectRuleType type;
  final String? stateId;
  final bool Function(TContext context)? condition;
  final String redirectTo;

  _RedirectRule({
    required this.type,
    this.stateId,
    this.condition,
    required this.redirectTo,
  });
}

/// Mixin for creating state-based redirects declaratively.
///
/// Example:
/// ```dart
/// class AuthRedirectGuard with StateBasedRedirect<AuthContext, AuthEvent> {
///   @override
///   final StateMachineActor<AuthContext, AuthEvent> actor;
///
///   AuthRedirectGuard(this.actor);
///
///   @override
///   List<RedirectRule> get rules => [
///     RedirectRule.whenNotMatches('authenticated', redirectTo: '/login'),
///     RedirectRule.whenContext((ctx) => !ctx.emailVerified, redirectTo: '/verify'),
///   ];
/// }
/// ```
mixin StateBasedRedirect<TContext, TEvent extends XEvent> {
  StateMachineActor<TContext, TEvent> get actor;
  List<RedirectRule<TContext>> get rules;
  List<String> get exceptPaths => [];

  String? redirect(BuildContext context, GoRouterState state) {
    for (final path in exceptPaths) {
      if (state.matchedLocation.startsWith(path)) {
        return null;
      }
    }

    for (final rule in rules) {
      final result = rule.evaluate(actor);
      if (result != null) {
        return result;
      }
    }

    return null;
  }
}

/// A declarative redirect rule.
abstract class RedirectRule<TContext> {
  String? evaluate<TEvent extends XEvent>(
    StateMachineActor<TContext, TEvent> actor,
  );

  /// Create a rule that redirects when state matches.
  factory RedirectRule.whenMatches(String stateId, {required String redirectTo}) =
      _MatchesRedirectRule<TContext>;

  /// Create a rule that redirects when state doesn't match.
  factory RedirectRule.whenNotMatches(String stateId, {required String redirectTo}) =
      _NotMatchesRedirectRule<TContext>;

  /// Create a rule that redirects based on context condition.
  factory RedirectRule.whenContext(
    bool Function(TContext context) condition, {
    required String redirectTo,
  }) = _ContextRedirectRule<TContext>;
}

class _MatchesRedirectRule<TContext> implements RedirectRule<TContext> {
  final String stateId;
  final String redirectTo;

  _MatchesRedirectRule(this.stateId, {required this.redirectTo});

  @override
  String? evaluate<TEvent extends XEvent>(
    StateMachineActor<TContext, TEvent> actor,
  ) {
    return actor.matches(stateId) ? redirectTo : null;
  }
}

class _NotMatchesRedirectRule<TContext> implements RedirectRule<TContext> {
  final String stateId;
  final String redirectTo;

  _NotMatchesRedirectRule(this.stateId, {required this.redirectTo});

  @override
  String? evaluate<TEvent extends XEvent>(
    StateMachineActor<TContext, TEvent> actor,
  ) {
    return !actor.matches(stateId) ? redirectTo : null;
  }
}

class _ContextRedirectRule<TContext> implements RedirectRule<TContext> {
  final bool Function(TContext context) condition;
  final String redirectTo;

  _ContextRedirectRule(this.condition, {required this.redirectTo});

  @override
  String? evaluate<TEvent extends XEvent>(
    StateMachineActor<TContext, TEvent> actor,
  ) {
    return condition(actor.snapshot.context) ? redirectTo : null;
  }
}

/// Extension to create a redirect function from a snapshot accessor.
extension SnapshotRedirectExtension<TContext, TEvent extends XEvent>
    on StateMachineActor<TContext, TEvent> {
  /// Creates a redirect builder for this actor.
  RedirectBuilder<TContext, TEvent> redirect() {
    return RedirectBuilder<TContext, TEvent>(this);
  }
}

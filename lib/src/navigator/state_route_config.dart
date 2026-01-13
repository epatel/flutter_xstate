import 'package:flutter/widgets.dart';

import '../core/state_snapshot.dart';
import '../core/state_value.dart';
import '../events/x_event.dart';
import 'state_machine_page.dart';

/// Signature for building a page from state and route parameters.
typedef StatePageBuilder<TContext, TEvent extends XEvent> =
    StateMachinePage Function(
      BuildContext context,
      StateSnapshot<TContext> snapshot,
      Map<String, String> pathParams,
    );

/// Signature for a guard function that determines if navigation is allowed.
typedef RouteGuard<TContext> =
    bool Function(
      StateSnapshot<TContext> snapshot,
      Map<String, String> pathParams,
    );

/// Signature for a redirect function that returns a path to redirect to.
typedef RouteRedirect<TContext> =
    String? Function(
      StateSnapshot<TContext> snapshot,
      Map<String, String> pathParams,
    );

/// Signature for converting URL parameters to a state machine event.
typedef ParamsToEvent<TContext, TEvent extends XEvent> =
    TEvent? Function(Map<String, String> pathParams, TContext context);

/// Signature for converting context to URL parameters.
typedef ContextToParams<TContext> =
    Map<String, String> Function(TContext context);

/// Configuration for mapping a state machine state to a route.
///
/// Example:
/// ```dart
/// StateRouteConfig<AuthContext, AuthEvent>(
///   stateId: 'loggedIn.profile',
///   path: '/profile/:userId',
///   pageBuilder: (context, snapshot, params) => StateMachinePage(
///     key: ValueKey('profile-${params['userId']}'),
///     stateId: 'loggedIn.profile',
///     child: ProfileScreen(userId: params['userId']!),
///     transitionBuilder: StateMachineTransitions.slideFromRight,
///   ),
///   paramsToEvent: (params, ctx) => LoadProfileEvent(params['userId']!),
///   contextToParams: (ctx) => {'userId': ctx.selectedUserId ?? ''},
///   guard: (snapshot, params) => snapshot.value.matches('loggedIn'),
/// )
/// ```
class StateRouteConfig<TContext, TEvent extends XEvent> {
  /// The state ID pattern to match.
  ///
  /// Supports wildcards:
  /// - `'loggedOut'` - matches exactly 'loggedOut'
  /// - `'loggedIn.*'` - matches 'loggedIn' and any child state
  /// - `'loggedIn.home'` - matches exactly 'loggedIn.home'
  final String stateId;

  /// The URL path for this route.
  ///
  /// Supports path parameters: `/user/:id`, `/profile/:userId/posts/:postId`
  final String path;

  /// Builder for creating the Page for this route.
  final StatePageBuilder<TContext, TEvent> pageBuilder;

  /// Child routes for nested navigation.
  final List<StateRouteConfig<TContext, TEvent>> children;

  /// Guard function - return false to prevent navigation to this route.
  final RouteGuard<TContext>? guard;

  /// Redirect function - return a path to redirect to, or null to proceed.
  final RouteRedirect<TContext>? redirect;

  /// Function to convert URL parameters to a state machine event.
  /// Called when navigating to this route via URL (deep linking).
  final ParamsToEvent<TContext, TEvent>? paramsToEvent;

  /// Function to extract URL parameters from context.
  /// Used when generating the URL from current state.
  final ContextToParams<TContext>? contextToParams;

  /// Creates a route configuration.
  const StateRouteConfig({
    required this.stateId,
    required this.path,
    required this.pageBuilder,
    this.children = const [],
    this.guard,
    this.redirect,
    this.paramsToEvent,
    this.contextToParams,
  });

  /// Check if this route matches the given state value string.
  ///
  /// The [stateValue] should be a dot-notation path like 'loggedIn.home'.
  /// Use [matchesStateValue] to match against a [StateValue] directly.
  bool matchesState(String stateValue) {
    if (stateId.endsWith('.*')) {
      // Wildcard pattern - match state and any children
      final prefix = stateId.substring(0, stateId.length - 2);
      return stateValue == prefix || stateValue.startsWith('$prefix.');
    }
    return stateValue == stateId || stateValue.startsWith('$stateId.');
  }

  /// Check if this route matches the given [StateValue].
  ///
  /// This uses the StateValue's built-in matching logic.
  bool matchesStateValue(dynamic stateValue) {
    if (stateId.endsWith('.*')) {
      // Wildcard pattern - match state and any children
      final prefix = stateId.substring(0, stateId.length - 2);
      // Check if state value matches the prefix
      if (stateValue is StateValue) {
        return stateValue.matches(prefix);
      }
    }
    // Use StateValue.matches for proper hierarchical matching
    if (stateValue is StateValue) {
      return stateValue.matches(stateId);
    }
    return false;
  }

  /// Extract path parameters from a URL path.
  ///
  /// Returns null if the path doesn't match this route's pattern.
  Map<String, String>? extractParams(String urlPath) {
    final patternSegments = path.split('/').where((s) => s.isNotEmpty).toList();
    final pathSegments = urlPath.split('/').where((s) => s.isNotEmpty).toList();

    if (patternSegments.length != pathSegments.length) return null;

    final params = <String, String>{};

    for (var i = 0; i < patternSegments.length; i++) {
      final patternSeg = patternSegments[i];
      final pathSeg = pathSegments[i];

      if (patternSeg.startsWith(':')) {
        // This is a parameter
        params[patternSeg.substring(1)] = pathSeg;
      } else if (patternSeg != pathSeg) {
        // Static segment doesn't match
        return null;
      }
    }

    return params;
  }

  /// Build the URL path from context using [contextToParams].
  String buildPath(TContext context) {
    if (contextToParams == null) return path;

    final params = contextToParams!(context);
    var result = path;

    for (final entry in params.entries) {
      result = result.replaceAll(':${entry.key}', entry.value);
    }

    return result;
  }
}

import 'package:flutter/material.dart';

import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../core/state_value.dart';
import '../events/x_event.dart';
import 'state_machine_page.dart';
import 'state_route_config.dart';

/// A [RouterDelegate] that builds pages based on state machine state.
///
/// This delegate listens to a [StateMachineActor] and rebuilds the navigation
/// stack whenever the state changes. It supports:
/// - Declarative state-to-route mapping
/// - Guards and redirects
/// - Deep linking with URL parameters
/// - Custom page transitions
///
/// Example:
/// ```dart
/// final routerDelegate = StateMachineRouterDelegate<AuthContext, AuthEvent>(
///   actor: authActor,
///   routes: [
///     StateRouteConfig(
///       stateId: 'loggedOut',
///       path: '/login',
///       pageBuilder: (ctx, snapshot, params) => StateMachinePage.fade(
///         stateId: 'loggedOut',
///         child: LoginScreen(),
///       ),
///     ),
///     StateRouteConfig(
///       stateId: 'loggedIn.*',
///       path: '/home',
///       pageBuilder: (ctx, snapshot, params) => StateMachinePage(
///         stateId: 'loggedIn',
///         child: HomeScreen(),
///       ),
///     ),
///   ],
/// );
/// ```
class StateMachineRouterDelegate<TContext, TEvent extends XEvent>
    extends RouterDelegate<RouteInformation>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<RouteInformation> {
  /// The state machine actor to listen to.
  final StateMachineActor<TContext, TEvent> actor;

  /// Route configurations mapping states to pages.
  final List<StateRouteConfig<TContext, TEvent>> routes;

  /// Default page to show when no route matches.
  final StateMachinePage Function(BuildContext context)? notFoundPageBuilder;

  /// Called when URL parameters trigger a state machine event.
  final void Function(TEvent event)? onNavigationEvent;

  /// Called when a guard prevents navigation.
  final void Function(StateRouteConfig<TContext, TEvent> route)?
  onGuardRejected;

  /// The navigator key for this delegate.
  @override
  final GlobalKey<NavigatorState> navigatorKey;

  /// Creates a router delegate for the given actor and routes.
  StateMachineRouterDelegate({
    required this.actor,
    required this.routes,
    this.notFoundPageBuilder,
    this.onNavigationEvent,
    this.onGuardRejected,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>() {
    // Listen to actor state changes
    actor.addListener(_onStateChanged);
  }

  RouteInformation? _pendingRouteInfo;
  List<StateMachinePage>? _cachedPages;
  String? _cachedStateString;

  void _onStateChanged() {
    _cachedPages = null;
    _cachedStateString = null;
    notifyListeners();
  }

  @override
  RouteInformation get currentConfiguration {
    final route = _findMatchingRoute(actor.snapshot);
    if (route != null) {
      final path = route.buildPath(actor.snapshot.context);
      return RouteInformation(uri: Uri.parse(path));
    }
    return RouteInformation(uri: Uri.parse('/'));
  }

  @override
  Future<void> setNewRoutePath(RouteInformation configuration) async {
    _pendingRouteInfo = configuration;
    final path = configuration.uri.path;

    // Find route that matches this URL
    for (final route in routes) {
      final params = route.extractParams(path);
      if (params != null) {
        // Check if we need to trigger an event
        if (route.paramsToEvent != null) {
          final event = route.paramsToEvent!(params, actor.snapshot.context);
          if (event != null) {
            onNavigationEvent?.call(event);
            actor.send(event);
          }
        }
        return;
      }
    }
  }

  /// Find the route that matches the current state.
  StateRouteConfig<TContext, TEvent>? _findMatchingRoute(
    StateSnapshot<TContext> snapshot,
  ) {
    final stateValue = snapshot.value;

    for (final route in routes) {
      if (route.matchesStateValue(stateValue)) {
        return route;
      }
    }

    // Check child routes recursively
    for (final route in routes) {
      final childRoute = _findInChildren(route.children, stateValue);
      if (childRoute != null) {
        return childRoute;
      }
    }

    return null;
  }

  StateRouteConfig<TContext, TEvent>? _findInChildren(
    List<StateRouteConfig<TContext, TEvent>> children,
    dynamic stateValue,
  ) {
    for (final route in children) {
      if (route.matchesStateValue(stateValue)) {
        return route;
      }
      final childRoute = _findInChildren(route.children, stateValue);
      if (childRoute != null) {
        return childRoute;
      }
    }
    return null;
  }

  /// Build the page stack for the current state.
  ///
  /// This builds a proper page stack for Navigator 2.0, including parent
  /// pages when in nested states. This ensures proper back animations.
  List<Page<dynamic>> _buildPages(BuildContext context) {
    final stateValue = actor.snapshot.value;
    final stateString = stateValue.toString();

    // Use cached pages if state hasn't changed
    if (_cachedPages != null && _cachedStateString == stateString) {
      return _cachedPages!;
    }

    final pages = <StateMachinePage>[];
    final snapshot = actor.snapshot;
    final addedStateIds = <String>{};

    // Sort routes by specificity (less specific first) to build proper stack
    // e.g., 'loggedIn' before 'loggedIn.home' before 'loggedIn.profile'
    final sortedRoutes = List<StateRouteConfig<TContext, TEvent>>.from(routes)
      ..sort((a, b) {
        final aDepth = a.stateId.split('.').length;
        final bDepth = b.stateId.split('.').length;
        return aDepth.compareTo(bDepth);
      });

    // Build page stack - add pages from least specific to most specific
    for (final route in sortedRoutes) {
      // Skip if we already added this state
      if (addedStateIds.contains(route.stateId)) continue;

      // Check if this route should be in the stack
      // A route is in the stack if:
      // 1. It matches the current state exactly, or
      // 2. The current state is a descendant of this route's state
      final shouldInclude =
          route.matchesStateValue(stateValue) ||
          _isAncestorState(route.stateId, stateValue);

      if (!shouldInclude) continue;

      final params = _extractCurrentParams(route);

      // Check guard
      if (route.guard != null && !route.guard!(snapshot, params)) {
        onGuardRejected?.call(route);
        continue;
      }

      // Check redirect
      if (route.redirect != null) {
        final redirectPath = route.redirect!(snapshot, params);
        if (redirectPath != null) {
          // Find and use the redirect route instead
          final redirectRoute = _findRouteByPath(redirectPath);
          if (redirectRoute != null) {
            final redirectParams =
                redirectRoute.extractParams(redirectPath) ?? {};
            pages.add(
              redirectRoute.pageBuilder(context, snapshot, redirectParams),
            );
            addedStateIds.add(route.stateId);
            continue;
          }
        }
      }

      pages.add(route.pageBuilder(context, snapshot, params));
      addedStateIds.add(route.stateId);
    }

    // If no pages matched, use not found or first route as fallback
    if (pages.isEmpty) {
      if (notFoundPageBuilder != null) {
        pages.add(notFoundPageBuilder!(context));
      } else if (routes.isNotEmpty) {
        // Fallback to first route
        final route = routes.first;
        pages.add(route.pageBuilder(context, snapshot, {}));
      }
    }

    _cachedPages = pages;
    _cachedStateString = stateString;
    return pages;
  }

  /// Check if [ancestorStateId] is an ancestor of [stateValue].
  bool _isAncestorState(String ancestorStateId, dynamic stateValue) {
    if (stateValue is! StateValue) return false;

    // Get the full state path as a string for comparison
    final currentStatePath = _getStateValuePath(stateValue);
    if (currentStatePath == null) return false;

    // Remove wildcard suffix if present
    var ancestorPath = ancestorStateId;
    if (ancestorPath.endsWith('.*')) {
      ancestorPath = ancestorPath.substring(0, ancestorPath.length - 2);
    }

    // Check if current state starts with ancestor path followed by a dot
    // e.g., 'loggedIn' is ancestor of 'loggedIn.profile'
    return currentStatePath.startsWith('$ancestorPath.') &&
        currentStatePath != ancestorPath;
  }

  /// Extract the dot-notation path from a StateValue.
  String? _getStateValuePath(StateValue stateValue) {
    // Use matches to find which path this state value represents
    // Try to match against known routes
    for (final route in routes) {
      var stateId = route.stateId;
      if (stateId.endsWith('.*')) {
        stateId = stateId.substring(0, stateId.length - 2);
      }
      if (stateValue.matches(stateId)) {
        // Found a matching route, now find the most specific match
        // by checking child states
        return _findMostSpecificMatch(stateValue, stateId);
      }
    }
    return null;
  }

  /// Find the most specific state path that matches the state value.
  String _findMostSpecificMatch(StateValue stateValue, String basePath) {
    // Check if any more specific route matches
    for (final route in routes) {
      var stateId = route.stateId;
      if (stateId.endsWith('.*')) {
        stateId = stateId.substring(0, stateId.length - 2);
      }
      // Check if this is a child of basePath and matches
      if (stateId.startsWith('$basePath.') && stateValue.matches(stateId)) {
        return _findMostSpecificMatch(stateValue, stateId);
      }
    }
    return basePath;
  }

  Map<String, String> _extractCurrentParams(
    StateRouteConfig<TContext, TEvent> route,
  ) {
    if (_pendingRouteInfo != null) {
      final params = route.extractParams(_pendingRouteInfo!.uri.path);
      if (params != null) return params;
    }

    // Build params from context
    if (route.contextToParams != null) {
      return route.contextToParams!(actor.snapshot.context);
    }

    return {};
  }

  StateRouteConfig<TContext, TEvent>? _findRouteByPath(String path) {
    for (final route in routes) {
      if (route.extractParams(path) != null) {
        return route;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: _buildPages(context),
      onDidRemovePage: (page) {
        // Page was removed from the stack
      },
    );
  }

  @override
  Future<bool> popRoute() async {
    if (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState?.pop();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    actor.removeListener(_onStateChanged);
    super.dispose();
  }
}

/// Extension to easily create a router delegate from an actor.
extension StateMachineActorRouterExtension<TContext, TEvent extends XEvent>
    on StateMachineActor<TContext, TEvent> {
  /// Create a [StateMachineRouterDelegate] for this actor.
  StateMachineRouterDelegate<TContext, TEvent> createRouterDelegate({
    required List<StateRouteConfig<TContext, TEvent>> routes,
    StateMachinePage Function(BuildContext context)? notFoundPageBuilder,
    void Function(TEvent event)? onNavigationEvent,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return StateMachineRouterDelegate<TContext, TEvent>(
      actor: this,
      routes: routes,
      notFoundPageBuilder: notFoundPageBuilder,
      onNavigationEvent: onNavigationEvent,
      navigatorKey: navigatorKey,
    );
  }
}

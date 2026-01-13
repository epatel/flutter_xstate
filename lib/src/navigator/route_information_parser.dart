import 'package:flutter/widgets.dart';

import '../events/x_event.dart';
import 'state_route_config.dart';

/// A [RouteInformationParser] for state machine navigation.
///
/// Parses URL paths and validates them against configured routes.
/// Supports path parameters extraction for deep linking.
///
/// Example:
/// ```dart
/// final parser = StateMachineRouteInformationParser<AuthContext, AuthEvent>(
///   routes: [
///     StateRouteConfig(stateId: 'home', path: '/'),
///     StateRouteConfig(stateId: 'profile', path: '/profile/:userId'),
///   ],
/// );
/// ```
class StateMachineRouteInformationParser<TContext, TEvent extends XEvent>
    extends RouteInformationParser<RouteInformation> {
  /// The route configurations to validate against.
  final List<StateRouteConfig<TContext, TEvent>> routes;

  /// The default path to use when no path is provided.
  final String defaultPath;

  /// Whether to use hash-based routing (/#/path instead of /path).
  final bool useHash;

  /// Creates a route information parser.
  const StateMachineRouteInformationParser({
    required this.routes,
    this.defaultPath = '/',
    this.useHash = false,
  });

  @override
  Future<RouteInformation> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    var path = routeInformation.uri.path;

    // Handle hash-based routing
    if (useHash) {
      final fragment = routeInformation.uri.fragment;
      if (fragment.isNotEmpty) {
        path = fragment.startsWith('/') ? fragment : '/$fragment';
      }
    }

    // Default to defaultPath if empty
    if (path.isEmpty || path == '/') {
      path = defaultPath;
    }

    // Validate the path exists in routes
    final matchingRoute = _findMatchingRoute(path);
    if (matchingRoute == null) {
      // Return default path if no match
      return RouteInformation(uri: Uri.parse(defaultPath));
    }

    return RouteInformation(uri: Uri.parse(path));
  }

  @override
  RouteInformation restoreRouteInformation(RouteInformation configuration) {
    final path = configuration.uri.path;

    if (useHash) {
      // Convert to hash-based URL
      return RouteInformation(
        uri: Uri(path: '/', fragment: path),
      );
    }

    return configuration;
  }

  /// Find a route that matches the given path.
  StateRouteConfig<TContext, TEvent>? _findMatchingRoute(String path) {
    for (final route in routes) {
      if (route.extractParams(path) != null) {
        return route;
      }

      // Check children
      final childMatch = _findInChildren(route.children, path);
      if (childMatch != null) {
        return childMatch;
      }
    }
    return null;
  }

  StateRouteConfig<TContext, TEvent>? _findInChildren(
    List<StateRouteConfig<TContext, TEvent>> children,
    String path,
  ) {
    for (final route in children) {
      if (route.extractParams(path) != null) {
        return route;
      }
      final childMatch = _findInChildren(route.children, path);
      if (childMatch != null) {
        return childMatch;
      }
    }
    return null;
  }

  /// Extract parameters from a path if it matches any route.
  Map<String, String>? extractParams(String path) {
    final route = _findMatchingRoute(path);
    return route?.extractParams(path);
  }
}

/// A simple route information parser that accepts any path.
///
/// Use this when you want full control over URL handling
/// and don't need route validation.
class SimpleRouteInformationParser
    extends RouteInformationParser<RouteInformation> {
  /// The default path when no path is provided.
  final String defaultPath;

  /// Creates a simple parser.
  const SimpleRouteInformationParser({this.defaultPath = '/'});

  @override
  Future<RouteInformation> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    var path = routeInformation.uri.path;

    if (path.isEmpty) {
      path = defaultPath;
    }

    return RouteInformation(uri: Uri.parse(path));
  }

  @override
  RouteInformation restoreRouteInformation(RouteInformation configuration) {
    return configuration;
  }
}

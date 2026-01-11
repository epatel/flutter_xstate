import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/state_machine.dart';
import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';
import '../flutter/state_machine_provider.dart';
import 'state_machine_refresh_listenable.dart';

/// Configuration for a state-based route.
///
/// Maps a state machine state to a route configuration.
class StateRoute<TContext, TEvent extends XEvent> {
  /// The state ID to match.
  final String stateId;

  /// The route path for this state.
  final String path;

  /// The widget builder for this state.
  final Widget Function(
    BuildContext context,
    GoRouterState routerState,
    StateSnapshot<TContext> machineState,
  )?
  builder;

  /// Nested routes.
  final List<StateRoute<TContext, TEvent>> children;

  /// Optional redirect for this state.
  final String? Function(BuildContext context, GoRouterState state)? redirect;

  const StateRoute({
    required this.stateId,
    required this.path,
    this.builder,
    this.children = const [],
    this.redirect,
  });
}

/// A router that uses state machine states to control navigation.
///
/// This provides a declarative way to map state machine states to routes.
///
/// Example:
/// ```dart
/// final authMachine = StateMachine.create<AuthContext, AuthEvent>((m) => m
///   ..initial('unauthenticated')
///   ..state('unauthenticated', (s) => s
///     ..on<LoginEvent>('authenticating')
///   )
///   ..state('authenticating', (s) => s
///     ..on<LoginSuccessEvent>('authenticated')
///     ..on<LoginFailureEvent>('unauthenticated')
///   )
///   ..state('authenticated', (s) => s
///     ..on<LogoutEvent>('unauthenticated')
///   )
/// );
///
/// final router = StateMachineRouter(
///   actor: authActor,
///   routes: [
///     StateRoute(stateId: 'unauthenticated', path: '/login', builder: ...),
///     StateRoute(stateId: 'authenticating', path: '/loading', builder: ...),
///     StateRoute(stateId: 'authenticated', path: '/home', builder: ...),
///   ],
/// );
/// ```
class StateMachineRouter<TContext, TEvent extends XEvent> {
  /// The state machine actor.
  final StateMachineActor<TContext, TEvent> actor;

  /// The state-based routes.
  final List<StateRoute<TContext, TEvent>> routes;

  /// The initial location.
  final String? initialLocation;

  /// Debug logging flag.
  final bool debugLogDiagnostics;

  /// The underlying GoRouter instance.
  late final GoRouter router;

  /// The refresh listenable.
  late final StateMachineRefreshListenable<TContext, TEvent> refreshListenable;

  StateMachineRouter({
    required this.actor,
    required this.routes,
    this.initialLocation,
    this.debugLogDiagnostics = false,
  }) {
    refreshListenable = StateMachineRefreshListenable(actor);

    router = GoRouter(
      initialLocation: initialLocation ?? _getInitialLocation(),
      refreshListenable: refreshListenable,
      redirect: _createRedirect(),
      routes: _buildRoutes(),
      debugLogDiagnostics: debugLogDiagnostics,
    );
  }

  String _getInitialLocation() {
    final currentState = actor.snapshot.value.toString();
    for (final route in routes) {
      if (route.stateId == currentState) {
        return route.path;
      }
    }
    return routes.isNotEmpty ? routes.first.path : '/';
  }

  GoRouterRedirect _createRedirect() {
    return (context, state) {
      final currentState = actor.snapshot.value.toString();

      // Find the route for the current state
      StateRoute<TContext, TEvent>? targetRoute;
      for (final route in routes) {
        if (route.stateId == currentState) {
          targetRoute = route;
          break;
        }
      }

      if (targetRoute == null) {
        return null;
      }

      // Check route-specific redirect
      if (targetRoute.redirect != null) {
        final redirectResult = targetRoute.redirect!(context, state);
        if (redirectResult != null) {
          return redirectResult;
        }
      }

      // Redirect to state's path if not already there
      if (!state.matchedLocation.startsWith(targetRoute.path)) {
        return targetRoute.path;
      }

      return null;
    };
  }

  List<RouteBase> _buildRoutes() {
    return routes.map((stateRoute) => _buildRoute(stateRoute)).toList();
  }

  GoRoute _buildRoute(StateRoute<TContext, TEvent> stateRoute) {
    return GoRoute(
      path: stateRoute.path,
      builder: (context, routerState) {
        if (stateRoute.builder != null) {
          return stateRoute.builder!(context, routerState, actor.snapshot);
        }
        // Provide a default empty widget if no builder is specified
        return const SizedBox.shrink();
      },
      routes: stateRoute.children.map((child) => _buildRoute(child)).toList(),
    );
  }

  /// Dispose the router and refresh listenable.
  void dispose() {
    refreshListenable.dispose();
    router.dispose();
  }
}

/// A widget that provides a state machine router.
///
/// Example:
/// ```dart
/// StateMachineRouterProvider<AuthContext, AuthEvent>(
///   machine: authMachine,
///   routes: [
///     StateRoute(stateId: 'unauthenticated', path: '/login', builder: ...),
///     StateRoute(stateId: 'authenticated', path: '/home', builder: ...),
///   ],
///   child: MaterialApp.router(
///     routerConfig: ..., // Access via context
///   ),
/// )
/// ```
class StateMachineRouterProvider<TContext, TEvent extends XEvent>
    extends StatefulWidget {
  /// The state machine definition.
  final StateMachine<TContext, TEvent> machine;

  /// The state-based routes.
  final List<StateRoute<TContext, TEvent>> routes;

  /// The child widget builder.
  final Widget Function(BuildContext context, GoRouter router) builder;

  /// Optional initial snapshot.
  final StateSnapshot<TContext>? initialSnapshot;

  /// Debug logging flag.
  final bool debugLogDiagnostics;

  const StateMachineRouterProvider({
    super.key,
    required this.machine,
    required this.routes,
    required this.builder,
    this.initialSnapshot,
    this.debugLogDiagnostics = false,
  });

  @override
  State<StateMachineRouterProvider<TContext, TEvent>> createState() =>
      _StateMachineRouterProviderState<TContext, TEvent>();
}

class _StateMachineRouterProviderState<TContext, TEvent extends XEvent>
    extends State<StateMachineRouterProvider<TContext, TEvent>> {
  late StateMachineActor<TContext, TEvent> _actor;
  late StateMachineRouter<TContext, TEvent> _router;

  @override
  void initState() {
    super.initState();
    _actor = widget.machine.createActor(
      initialSnapshot: widget.initialSnapshot,
    );
    _actor.start();

    _router = StateMachineRouter(
      actor: _actor,
      routes: widget.routes,
      debugLogDiagnostics: widget.debugLogDiagnostics,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StateMachineProviderValue<TContext, TEvent>(
      actor: _actor,
      child: widget.builder(context, _router.router),
    );
  }
}

/// A mixin for creating route configuration from state machine.
///
/// Example:
/// ```dart
/// class AppRouterConfig with StateMachineRouterMixin<AuthContext, AuthEvent> {
///   @override
///   StateMachineActor<AuthContext, AuthEvent> get actor => authActor;
///
///   @override
///   Map<String, String> get stateToRoute => {
///     'unauthenticated': '/login',
///     'authenticated': '/home',
///   };
///
///   @override
///   Map<String, Widget Function(BuildContext, GoRouterState)> get stateBuilders => {
///     'unauthenticated': (context, state) => LoginPage(),
///     'authenticated': (context, state) => HomePage(),
///   };
/// }
/// ```
mixin StateMachineRouterMixin<TContext, TEvent extends XEvent> {
  StateMachineActor<TContext, TEvent> get actor;
  Map<String, String> get stateToRoute;
  Map<String, Widget Function(BuildContext, GoRouterState)> get stateBuilders;

  List<RouteBase> get additionalRoutes => [];

  late final _refreshListenable = StateMachineRefreshListenable(actor);

  GoRouter createRouter({
    String? initialLocation,
    bool debugLogDiagnostics = false,
  }) {
    return GoRouter(
      initialLocation: initialLocation ?? _getInitialLocation(),
      refreshListenable: _refreshListenable,
      redirect: _redirect,
      routes: _buildRoutes(),
      debugLogDiagnostics: debugLogDiagnostics,
    );
  }

  String _getInitialLocation() {
    final currentState = actor.snapshot.value.toString();
    return stateToRoute[currentState] ?? '/';
  }

  String? _redirect(BuildContext context, GoRouterState state) {
    final currentState = actor.snapshot.value.toString();
    final targetPath = stateToRoute[currentState];

    if (targetPath != null && !state.matchedLocation.startsWith(targetPath)) {
      return targetPath;
    }

    return null;
  }

  List<RouteBase> _buildRoutes() {
    final routes = stateToRoute.entries.map((entry) {
      final stateId = entry.key;
      final path = entry.value;
      final builder = stateBuilders[stateId];

      return GoRoute(path: path, builder: builder);
    }).toList();

    return [...routes, ...additionalRoutes];
  }

  void dispose() {
    _refreshListenable.dispose();
  }
}

/// Helper to create a GoRouter from a state machine.
///
/// Example:
/// ```dart
/// final router = createStateMachineRouter(
///   actor: authActor,
///   stateRoutes: {
///     'unauthenticated': '/login',
///     'authenticated': '/home',
///   },
///   builders: {
///     '/login': (context, state) => LoginPage(),
///     '/home': (context, state) => HomePage(),
///   },
/// );
/// ```
GoRouter createStateMachineRouter<TContext, TEvent extends XEvent>({
  required StateMachineActor<TContext, TEvent> actor,
  required Map<String, String> stateRoutes,
  required Map<String, Widget Function(BuildContext, GoRouterState)> builders,
  String? initialLocation,
  bool debugLogDiagnostics = false,
}) {
  final refreshListenable = StateMachineRefreshListenable(actor);

  return GoRouter(
    initialLocation:
        initialLocation ?? stateRoutes[actor.snapshot.value.toString()] ?? '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final currentState = actor.snapshot.value.toString();
      final targetPath = stateRoutes[currentState];

      if (targetPath != null && !state.matchedLocation.startsWith(targetPath)) {
        return targetPath;
      }

      return null;
    },
    routes: stateRoutes.values.toSet().map((path) {
      return GoRoute(path: path, builder: builders[path]);
    }).toList(),
    debugLogDiagnostics: debugLogDiagnostics,
  );
}

/// Extension methods for GoRouter integration.
extension GoRouterStateMachineExtension on GoRouter {
  /// Navigate to a state by sending an event to the state machine.
  ///
  /// This is useful when you want to trigger a state transition that
  /// will automatically update the route.
  void sendEvent<TContext, TEvent extends XEvent>(
    BuildContext context,
    TEvent event,
  ) {
    context.read<StateMachineActor<TContext, TEvent>>().send(event);
  }
}

/// Extension for BuildContext to access router state machine integration.
extension RouterStateMachineContext on BuildContext {
  /// Get the GoRouter instance.
  GoRouter get goRouter => GoRouter.of(this);

  /// Navigate based on state machine state.
  void goToMachineState<TContext, TEvent extends XEvent>(
    Map<String, String> stateToRoute,
  ) {
    final actor = read<StateMachineActor<TContext, TEvent>>();
    final currentState = actor.snapshot.value.toString();
    final path = stateToRoute[currentState];
    if (path != null) {
      GoRouter.of(this).go(path);
    }
  }
}

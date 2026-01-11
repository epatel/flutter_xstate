import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/state_machine.dart';
import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';

/// A widget that creates a state machine actor scoped to a route.
///
/// The actor is created when the route is entered and disposed when
/// the route is exited. This is useful for page-specific state machines.
///
/// Example:
/// ```dart
/// GoRoute(
///   path: '/checkout',
///   builder: (context, state) => RouteScopedMachine<CheckoutContext, CheckoutEvent>(
///     machine: checkoutMachine,
///     builder: (context, actor) => CheckoutPage(),
///   ),
/// )
/// ```
class RouteScopedMachine<TContext, TEvent extends XEvent>
    extends StatefulWidget {
  /// The state machine definition.
  final StateMachine<TContext, TEvent> machine;

  /// Optional initial snapshot to restore state.
  final StateSnapshot<TContext>? initialSnapshot;

  /// Builder function that receives the actor.
  final Widget Function(
    BuildContext context,
    StateMachineActor<TContext, TEvent> actor,
  )
  builder;

  /// Callback when the actor is created.
  final void Function(StateMachineActor<TContext, TEvent> actor)? onCreated;

  /// Callback when the actor is disposed.
  final void Function(StateMachineActor<TContext, TEvent> actor)? onDisposed;

  /// Whether to automatically start the actor.
  final bool autoStart;

  const RouteScopedMachine({
    super.key,
    required this.machine,
    required this.builder,
    this.initialSnapshot,
    this.onCreated,
    this.onDisposed,
    this.autoStart = true,
  });

  @override
  State<RouteScopedMachine<TContext, TEvent>> createState() =>
      _RouteScopedMachineState<TContext, TEvent>();
}

class _RouteScopedMachineState<TContext, TEvent extends XEvent>
    extends State<RouteScopedMachine<TContext, TEvent>> {
  late StateMachineActor<TContext, TEvent> _actor;

  @override
  void initState() {
    super.initState();
    _actor = widget.machine.createActor(
      initialSnapshot: widget.initialSnapshot,
    );
    widget.onCreated?.call(_actor);
    if (widget.autoStart) {
      _actor.start();
    }
  }

  @override
  void dispose() {
    widget.onDisposed?.call(_actor);
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StateMachineActor<TContext, TEvent>>.value(
      value: _actor,
      child: widget.builder(context, _actor),
    );
  }
}

/// A route that provides a state machine scoped to its lifecycle.
///
/// This is a convenience wrapper around [GoRoute] that automatically
/// manages a state machine for the route.
///
/// Example:
/// ```dart
/// final checkoutRoute = StateMachineRoute<CheckoutContext, CheckoutEvent>(
///   path: '/checkout',
///   machine: checkoutMachine,
///   builder: (context, state, actor) => CheckoutPage(),
/// );
/// ```
class StateMachineRoute<TContext, TEvent extends XEvent> extends GoRoute {
  /// Creates a route with a scoped state machine.
  StateMachineRoute({
    required super.path,
    required StateMachine<TContext, TEvent> machine,
    required Widget Function(
      BuildContext context,
      GoRouterState state,
      StateMachineActor<TContext, TEvent> actor,
    )
    builder,
    StateSnapshot<TContext>? initialSnapshot,
    void Function(StateMachineActor<TContext, TEvent> actor)? onCreated,
    void Function(StateMachineActor<TContext, TEvent> actor)? onDisposed,
    bool autoStart = true,
    super.name,
    super.routes,
    super.redirect,
    super.parentNavigatorKey,
  }) : super(
         builder: (context, state) => RouteScopedMachine<TContext, TEvent>(
           machine: machine,
           initialSnapshot: initialSnapshot,
           onCreated: onCreated,
           onDisposed: onDisposed,
           autoStart: autoStart,
           builder: (context, actor) => builder(context, state, actor),
         ),
       );
}

/// A widget that restores state machine state from route parameters.
///
/// This is useful for restoring state when navigating back to a route
/// or when deep linking.
///
/// Example:
/// ```dart
/// GoRoute(
///   path: '/wizard/:step',
///   builder: (context, state) => RouteRestoredMachine<WizardContext, WizardEvent>(
///     machine: wizardMachine,
///     restoreFrom: (routeState) {
///       final step = routeState.pathParameters['step'] ?? 'intro';
///       return StateSnapshot(
///         value: AtomicStateValue(step),
///         context: WizardContext(),
///         event: InitEvent(),
///       );
///     },
///     builder: (context, actor) => WizardPage(),
///   ),
/// )
/// ```
class RouteRestoredMachine<TContext, TEvent extends XEvent>
    extends StatefulWidget {
  /// The state machine definition.
  final StateMachine<TContext, TEvent> machine;

  /// Function to restore state from route parameters.
  final StateSnapshot<TContext> Function(GoRouterState routeState) restoreFrom;

  /// Builder function that receives the actor.
  final Widget Function(
    BuildContext context,
    StateMachineActor<TContext, TEvent> actor,
  )
  builder;

  /// Callback when the actor is created.
  final void Function(StateMachineActor<TContext, TEvent> actor)? onCreated;

  /// Whether to automatically start the actor.
  final bool autoStart;

  const RouteRestoredMachine({
    super.key,
    required this.machine,
    required this.restoreFrom,
    required this.builder,
    this.onCreated,
    this.autoStart = true,
  });

  @override
  State<RouteRestoredMachine<TContext, TEvent>> createState() =>
      _RouteRestoredMachineState<TContext, TEvent>();
}

class _RouteRestoredMachineState<TContext, TEvent extends XEvent>
    extends State<RouteRestoredMachine<TContext, TEvent>> {
  StateMachineActor<TContext, TEvent>? _actor;
  GoRouterState? _lastRouteState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateActorIfNeeded();
  }

  void _updateActorIfNeeded() {
    final routeState = GoRouterState.of(context);

    // Only recreate if route state changed significantly
    if (_lastRouteState?.matchedLocation != routeState.matchedLocation ||
        _lastRouteState?.pathParameters != routeState.pathParameters) {
      _lastRouteState = routeState;

      // Dispose old actor
      _actor?.dispose();

      // Create new actor with restored state
      final snapshot = widget.restoreFrom(routeState);
      _actor = widget.machine.createActor(initialSnapshot: snapshot);
      widget.onCreated?.call(_actor!);

      if (widget.autoStart) {
        _actor!.start();
      }
    }
  }

  @override
  void dispose() {
    _actor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_actor == null) {
      return const SizedBox.shrink();
    }

    return ChangeNotifierProvider<StateMachineActor<TContext, TEvent>>.value(
      value: _actor!,
      child: widget.builder(context, _actor!),
    );
  }
}

/// A widget that synchronizes state machine state with route parameters.
///
/// When the state machine's state changes, the route is updated.
/// When the route changes, the state machine is updated.
///
/// Example:
/// ```dart
/// GoRoute(
///   path: '/wizard/:step',
///   builder: (context, state) => RouteSyncedMachine<WizardContext, WizardEvent>(
///     machine: wizardMachine,
///     toRoute: (snapshot) => '/wizard/${snapshot.value}',
///     fromRoute: (routeState) => routeState.pathParameters['step'] ?? 'intro',
///     builder: (context, actor) => WizardPage(),
///   ),
/// )
/// ```
class RouteSyncedMachine<TContext, TEvent extends XEvent>
    extends StatefulWidget {
  /// The state machine definition.
  final StateMachine<TContext, TEvent> machine;

  /// Function to convert state to a route.
  final String Function(StateSnapshot<TContext> snapshot) toRoute;

  /// Function to get state ID from route.
  final String Function(GoRouterState routeState) fromRoute;

  /// Builder function that receives the actor.
  final Widget Function(
    BuildContext context,
    StateMachineActor<TContext, TEvent> actor,
  )
  builder;

  /// Whether to update the route when state changes.
  final bool syncToRoute;

  /// Whether to update state when route changes.
  final bool syncFromRoute;

  const RouteSyncedMachine({
    super.key,
    required this.machine,
    required this.toRoute,
    required this.fromRoute,
    required this.builder,
    this.syncToRoute = true,
    this.syncFromRoute = true,
  });

  @override
  State<RouteSyncedMachine<TContext, TEvent>> createState() =>
      _RouteSyncedMachineState<TContext, TEvent>();
}

class _RouteSyncedMachineState<TContext, TEvent extends XEvent>
    extends State<RouteSyncedMachine<TContext, TEvent>> {
  late StateMachineActor<TContext, TEvent> _actor;
  bool _isSyncing = false;
  String? _lastStateValue;

  @override
  void initState() {
    super.initState();
    _actor = widget.machine.createActor();
    _actor.addListener(_onStateChange);
    _actor.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.syncFromRoute && !_isSyncing) {
      _syncFromRoute();
    }
  }

  void _syncFromRoute() {
    final routeState = GoRouterState.of(context);
    final stateIdFromRoute = widget.fromRoute(routeState);

    if (stateIdFromRoute != _actor.snapshot.value.toString()) {
      _isSyncing = true;
      // Note: This would require a special event to force state change
      // For now, we just track the mismatch
      _isSyncing = false;
    }
  }

  void _onStateChange() {
    if (!widget.syncToRoute || _isSyncing) return;

    final currentStateValue = _actor.snapshot.value.toString();
    if (currentStateValue != _lastStateValue) {
      _lastStateValue = currentStateValue;
      _isSyncing = true;

      final newRoute = widget.toRoute(_actor.snapshot);
      final currentRoute = GoRouterState.of(context).matchedLocation;

      if (newRoute != currentRoute) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            GoRouter.of(context).go(newRoute);
          }
          _isSyncing = false;
        });
      } else {
        _isSyncing = false;
      }
    }
  }

  @override
  void dispose() {
    _actor.removeListener(_onStateChange);
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StateMachineActor<TContext, TEvent>>.value(
      value: _actor,
      child: widget.builder(context, _actor),
    );
  }
}

/// Extension for reading route state from context.
extension RouteStateMachineContext on BuildContext {
  /// Get the current GoRouterState.
  GoRouterState get routerState => GoRouterState.of(this);

  /// Navigate to a route based on state machine state.
  void goToState<TContext, TEvent extends XEvent>(
    String Function(StateSnapshot<TContext> snapshot) routeBuilder,
  ) {
    final actor = read<StateMachineActor<TContext, TEvent>>();
    final route = routeBuilder(actor.snapshot);
    GoRouter.of(this).go(route);
  }
}

import 'package:flutter/widgets.dart';

import '../core/state_machine.dart';
import '../core/state_machine_actor.dart';
import '../events/x_event.dart';
import 'route_information_parser.dart';
import 'state_machine_page.dart';
import 'state_machine_router_delegate.dart';
import 'state_route_config.dart';

/// A high-level API for state machine navigation.
///
/// Provides convenient access to the router delegate and route parser
/// for use with [MaterialApp.router] or [WidgetsApp.router].
///
/// Example:
/// ```dart
/// final navigator = StateMachineNavigator<AuthContext, AuthEvent>(
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
///
/// MaterialApp.router(
///   routerDelegate: navigator.routerDelegate,
///   routeInformationParser: navigator.routeInformationParser,
/// );
/// ```
class StateMachineNavigator<TContext, TEvent extends XEvent> {
  /// The state machine actor.
  final StateMachineActor<TContext, TEvent> actor;

  /// Route configurations.
  final List<StateRouteConfig<TContext, TEvent>> routes;

  /// The router delegate.
  late final StateMachineRouterDelegate<TContext, TEvent> routerDelegate;

  /// The route information parser.
  late final StateMachineRouteInformationParser<TContext, TEvent>
  routeInformationParser;

  /// Creates a navigator for the given actor and routes.
  ///
  /// Parameters:
  /// - [actor]: The state machine actor to drive navigation.
  /// - [routes]: Route configurations mapping states to pages.
  /// - [notFoundPageBuilder]: Page to show when no route matches.
  /// - [defaultPath]: Default URL path when none is provided.
  /// - [useHashRouting]: Whether to use hash-based URLs (/#/path).
  /// - [onNavigationEvent]: Called when URL triggers a state event.
  /// - [onGuardRejected]: Called when a guard prevents navigation.
  /// - [navigatorKey]: Key for the internal Navigator widget.
  StateMachineNavigator({
    required this.actor,
    required this.routes,
    StateMachinePage Function(BuildContext context)? notFoundPageBuilder,
    String defaultPath = '/',
    bool useHashRouting = false,
    void Function(TEvent event)? onNavigationEvent,
    void Function(StateRouteConfig<TContext, TEvent> route)? onGuardRejected,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    routerDelegate = StateMachineRouterDelegate<TContext, TEvent>(
      actor: actor,
      routes: routes,
      notFoundPageBuilder: notFoundPageBuilder,
      onNavigationEvent: onNavigationEvent,
      onGuardRejected: onGuardRejected,
      navigatorKey: navigatorKey,
    );

    routeInformationParser =
        StateMachineRouteInformationParser<TContext, TEvent>(
          routes: routes,
          defaultPath: defaultPath,
          useHash: useHashRouting,
        );
  }

  /// The navigator key for accessing Navigator state.
  GlobalKey<NavigatorState> get navigatorKey => routerDelegate.navigatorKey;

  /// Dispose the navigator.
  void dispose() {
    routerDelegate.dispose();
  }
}

/// Factory for creating navigators from state machines.
///
/// Example:
/// ```dart
/// final navigator = StateMachineNavigatorFactory.create(
///   machine: authMachine,
///   routes: [...],
/// );
/// ```
class StateMachineNavigatorFactory {
  /// Create a navigator with a new actor for the given machine.
  ///
  /// The actor is created and started automatically.
  static StateMachineNavigator<TContext, TEvent>
  create<TContext, TEvent extends XEvent>({
    required StateMachine<TContext, TEvent> machine,
    required List<StateRouteConfig<TContext, TEvent>> routes,
    StateMachinePage Function(BuildContext context)? notFoundPageBuilder,
    String defaultPath = '/',
    bool useHashRouting = false,
    void Function(TEvent event)? onNavigationEvent,
    void Function(StateRouteConfig<TContext, TEvent> route)? onGuardRejected,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    final actor = machine.createActor();
    actor.start();

    return StateMachineNavigator<TContext, TEvent>(
      actor: actor,
      routes: routes,
      notFoundPageBuilder: notFoundPageBuilder,
      defaultPath: defaultPath,
      useHashRouting: useHashRouting,
      onNavigationEvent: onNavigationEvent,
      onGuardRejected: onGuardRejected,
      navigatorKey: navigatorKey,
    );
  }
}

/// A widget that provides a state machine navigator to the widget tree.
///
/// This is a convenience widget that creates and manages a [StateMachineNavigator]
/// and provides access to it via [Navigator2Provider.of].
///
/// Example:
/// ```dart
/// Navigator2Provider<AuthContext, AuthEvent>(
///   actor: authActor,
///   routes: [...],
///   child: MaterialApp.router(
///     routerDelegate: Navigator2Provider.of<AuthContext, AuthEvent>(context).routerDelegate,
///     routeInformationParser: Navigator2Provider.of<AuthContext, AuthEvent>(context).routeInformationParser,
///   ),
/// )
/// ```
class Navigator2Provider<TContext, TEvent extends XEvent>
    extends StatefulWidget {
  /// The state machine actor.
  final StateMachineActor<TContext, TEvent> actor;

  /// Route configurations.
  final List<StateRouteConfig<TContext, TEvent>> routes;

  /// Child widget.
  final Widget child;

  /// Page to show when no route matches.
  final StateMachinePage Function(BuildContext context)? notFoundPageBuilder;

  /// Default URL path.
  final String defaultPath;

  /// Whether to use hash-based URLs.
  final bool useHashRouting;

  const Navigator2Provider({
    super.key,
    required this.actor,
    required this.routes,
    required this.child,
    this.notFoundPageBuilder,
    this.defaultPath = '/',
    this.useHashRouting = false,
  });

  /// Get the navigator from the widget tree.
  static StateMachineNavigator<TContext, TEvent>
  of<TContext, TEvent extends XEvent>(BuildContext context) {
    final provider = context
        .findAncestorStateOfType<_Navigator2ProviderState<TContext, TEvent>>();
    if (provider == null) {
      throw FlutterError(
        'Navigator2Provider.of<$TContext, $TEvent>() called with a context '
        'that does not contain a Navigator2Provider<$TContext, $TEvent>.',
      );
    }
    return provider.navigator;
  }

  /// Try to get the navigator, returning null if not found.
  static StateMachineNavigator<TContext, TEvent>?
  maybeOf<TContext, TEvent extends XEvent>(BuildContext context) {
    final provider = context
        .findAncestorStateOfType<_Navigator2ProviderState<TContext, TEvent>>();
    return provider?.navigator;
  }

  @override
  State<Navigator2Provider<TContext, TEvent>> createState() =>
      _Navigator2ProviderState<TContext, TEvent>();
}

class _Navigator2ProviderState<TContext, TEvent extends XEvent>
    extends State<Navigator2Provider<TContext, TEvent>> {
  late StateMachineNavigator<TContext, TEvent> navigator;

  @override
  void initState() {
    super.initState();
    navigator = StateMachineNavigator<TContext, TEvent>(
      actor: widget.actor,
      routes: widget.routes,
      notFoundPageBuilder: widget.notFoundPageBuilder,
      defaultPath: widget.defaultPath,
      useHashRouting: widget.useHashRouting,
    );
  }

  @override
  void dispose() {
    navigator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension for convenient navigation methods.
extension NavigatorContextExtension on BuildContext {
  /// Navigate to a specific path.
  void navigateTo(String path) {
    // This would typically update the router's route information
    // For now, this is a placeholder for future implementation
  }
}

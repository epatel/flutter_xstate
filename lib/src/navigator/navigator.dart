/// Navigator 2.0 integration for flutter_xstate.
///
/// This module provides a Navigator 2.0 based router that:
/// - Maps state machine states to pages/routes
/// - Supports deep linking with URL parameters
/// - Provides full control over page transitions
/// - Handles guards and redirects
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:flutter_xstate/navigator.dart';
///
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
///   ],
/// );
///
/// MaterialApp.router(
///   routerDelegate: navigator.routerDelegate,
///   routeInformationParser: navigator.routeInformationParser,
/// );
/// ```
///
/// ## Custom Transitions
///
/// ```dart
/// StateMachinePage(
///   stateId: 'home',
///   child: HomeScreen(),
///   transitionBuilder: StateMachineTransitions.slideFromRight,
///   transitionDuration: Duration(milliseconds: 400),
/// )
/// ```
///
/// ## Deep Linking
///
/// ```dart
/// StateRouteConfig(
///   stateId: 'profile',
///   path: '/profile/:userId',
///   paramsToEvent: (params, ctx) => LoadProfileEvent(params['userId']!),
///   contextToParams: (ctx) => {'userId': ctx.userId},
/// )
/// ```
library;

export 'route_information_parser.dart';
export 'scoped_page.dart';
export 'state_machine_navigator.dart';
export 'state_machine_page.dart';
export 'state_machine_router_delegate.dart';
export 'state_route_config.dart';
export 'transitions.dart';

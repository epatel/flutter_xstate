import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';
import 'state_machine_provider.dart';

/// Builds a widget in response to state machine changes.
///
/// [StateMachineBuilder] rebuilds whenever the state machine's state changes.
/// It receives the current state and a send function to dispatch events.
///
/// Example:
/// ```dart
/// StateMachineBuilder<AuthContext, AuthEvent>(
///   builder: (context, state, send) {
///     if (state.matches('authenticated')) {
///       return HomePage(
///         user: state.context.user,
///         onLogout: () => send(LogoutEvent()),
///       );
///     }
///     return LoginPage(
///       onLogin: (email, password) => send(LoginEvent(email, password)),
///     );
///   },
/// )
/// ```
class StateMachineBuilder<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// Builder function that creates the widget.
  ///
  /// Called whenever the state machine's state changes.
  final Widget Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    SendEvent<TEvent> send,
  ) builder;

  /// Optional condition to determine if the widget should rebuild.
  ///
  /// If provided, the widget only rebuilds when this returns true.
  /// Useful for optimizing rebuilds when only certain state changes matter.
  final bool Function(
    StateSnapshot<TContext> previous,
    StateSnapshot<TContext> current,
  )? buildWhen;

  const StateMachineBuilder({
    super.key,
    required this.builder,
    this.buildWhen,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<StateMachineActor<TContext, TEvent>,
        StateSnapshot<TContext>>(
      selector: (_, actor) => actor.snapshot,
      shouldRebuild: buildWhen ?? (previous, current) => previous != current,
      builder: (context, state, child) {
        final actor = context.read<StateMachineActor<TContext, TEvent>>();
        return builder(context, state, actor.send);
      },
    );
  }
}

/// Builds a widget based on whether the state machine matches a state.
///
/// This is a convenience widget for conditional rendering based on state.
///
/// Example:
/// ```dart
/// StateMachineMatchBuilder<AuthContext, AuthEvent>(
///   stateId: 'loading',
///   matchBuilder: (context, state, send) => LoadingSpinner(),
///   orElse: (context, state, send) => ContentView(),
/// )
/// ```
class StateMachineMatchBuilder<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// The state ID to match.
  final String stateId;

  /// Builder when the state matches.
  final Widget Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    SendEvent<TEvent> send,
  ) matchBuilder;

  /// Builder when the state does not match.
  final Widget Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    SendEvent<TEvent> send,
  )? orElse;

  const StateMachineMatchBuilder({
    super.key,
    required this.stateId,
    required this.matchBuilder,
    this.orElse,
  });

  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<TContext, TEvent>(
      buildWhen: (previous, current) =>
          previous.matches(stateId) != current.matches(stateId),
      builder: (context, state, send) {
        if (state.matches(stateId)) {
          return matchBuilder(context, state, send);
        }
        return orElse?.call(context, state, send) ?? const SizedBox.shrink();
      },
    );
  }
}

/// Builds different widgets based on multiple state conditions.
///
/// Example:
/// ```dart
/// StateMachineCaseBuilder<AuthContext, AuthEvent>(
///   cases: {
///     'loading': (context, state, send) => LoadingSpinner(),
///     'authenticated': (context, state, send) => HomePage(),
///     'error': (context, state, send) => ErrorPage(),
///   },
///   orElse: (context, state, send) => LoginPage(),
/// )
/// ```
class StateMachineCaseBuilder<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// Map of state IDs to builder functions.
  final Map<
      String,
      Widget Function(
        BuildContext context,
        StateSnapshot<TContext> state,
        SendEvent<TEvent> send,
      )> cases;

  /// Builder when no case matches.
  final Widget Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    SendEvent<TEvent> send,
  )? orElse;

  const StateMachineCaseBuilder({
    super.key,
    required this.cases,
    this.orElse,
  });

  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<TContext, TEvent>(
      builder: (context, state, send) {
        for (final entry in cases.entries) {
          if (state.matches(entry.key)) {
            return entry.value(context, state, send);
          }
        }
        return orElse?.call(context, state, send) ?? const SizedBox.shrink();
      },
    );
  }
}

/// Builds a widget only when the context satisfies a condition.
///
/// Similar to [StateMachineBuilder] but with a focus on context-based
/// conditional rendering.
///
/// Example:
/// ```dart
/// StateMachineContextBuilder<CartContext, CartEvent>(
///   condition: (context) => context.items.isNotEmpty,
///   builder: (context, state, send) => CheckoutButton(),
///   orElse: (context, state, send) => EmptyCartMessage(),
/// )
/// ```
class StateMachineContextBuilder<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// Condition based on the context.
  final bool Function(TContext context) condition;

  /// Builder when the condition is true.
  final Widget Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    SendEvent<TEvent> send,
  ) builder;

  /// Builder when the condition is false.
  final Widget Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    SendEvent<TEvent> send,
  )? orElse;

  const StateMachineContextBuilder({
    super.key,
    required this.condition,
    required this.builder,
    this.orElse,
  });

  @override
  Widget build(BuildContext context) {
    return StateMachineBuilder<TContext, TEvent>(
      buildWhen: (previous, current) =>
          condition(previous.context) != condition(current.context),
      builder: (context, state, send) {
        if (condition(state.context)) {
          return builder(context, state, send);
        }
        return orElse?.call(context, state, send) ?? const SizedBox.shrink();
      },
    );
  }
}

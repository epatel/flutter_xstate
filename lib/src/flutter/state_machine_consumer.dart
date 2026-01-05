import 'package:flutter/widgets.dart';

import '../core/state_snapshot.dart';
import '../events/x_event.dart';
import 'state_machine_builder.dart';
import 'state_machine_listener.dart';
import 'state_machine_provider.dart';

/// Combines [StateMachineBuilder] and [StateMachineListener] in one widget.
///
/// Use this when you need both reactive UI building and side effects
/// in response to state changes.
///
/// Example:
/// ```dart
/// StateMachineConsumer<AuthContext, AuthEvent>(
///   listener: (context, state) {
///     if (state.matches('error')) {
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text(state.context.errorMessage)),
///       );
///     }
///   },
///   builder: (context, state, send) {
///     if (state.matches('loading')) {
///       return LoadingSpinner();
///     }
///     if (state.matches('authenticated')) {
///       return HomePage();
///     }
///     return LoginPage(onLogin: () => send(LoginEvent()));
///   },
/// )
/// ```
class StateMachineConsumer<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// Listener callback for side effects.
  final void Function(
    BuildContext context,
    StateSnapshot<TContext> state,
  ) listener;

  /// Builder function for the UI.
  final Widget Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    SendEvent<TEvent> send,
  ) builder;

  /// Optional condition for when to call the listener.
  final bool Function(
    StateSnapshot<TContext> previous,
    StateSnapshot<TContext> current,
  )? listenWhen;

  /// Optional condition for when to rebuild.
  final bool Function(
    StateSnapshot<TContext> previous,
    StateSnapshot<TContext> current,
  )? buildWhen;

  const StateMachineConsumer({
    super.key,
    required this.listener,
    required this.builder,
    this.listenWhen,
    this.buildWhen,
  });

  @override
  Widget build(BuildContext context) {
    return StateMachineListener<TContext, TEvent>(
      listener: listener,
      listenWhen: listenWhen,
      child: StateMachineBuilder<TContext, TEvent>(
        builder: builder,
        buildWhen: buildWhen,
      ),
    );
  }
}

/// Consumer that also provides access to a selected value.
///
/// Combines the features of [StateMachineSelector] with listener capabilities.
///
/// Example:
/// ```dart
/// StateMachineSelectorConsumer<CartContext, CartEvent, double>(
///   selector: (context) => context.totalPrice,
///   listener: (context, state, price) {
///     if (price > 100) {
///       showFreeShippingBanner(context);
///     }
///   },
///   builder: (context, state, price, send) {
///     return Text('Total: \$${price.toStringAsFixed(2)}');
///   },
/// )
/// ```
class StateMachineSelectorConsumer<TContext, TEvent extends XEvent, TSelected>
    extends StatefulWidget {
  /// Function to select a value from the context.
  final TSelected Function(TContext context) selector;

  /// Listener callback with the selected value.
  final void Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    TSelected value,
  ) listener;

  /// Builder function with the selected value.
  final Widget Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    TSelected value,
    SendEvent<TEvent> send,
  ) builder;

  /// Optional condition for when to call the listener.
  final bool Function(TSelected previous, TSelected current)? listenWhen;

  /// Optional condition for when to rebuild.
  final bool Function(TSelected previous, TSelected current)? buildWhen;

  const StateMachineSelectorConsumer({
    super.key,
    required this.selector,
    required this.listener,
    required this.builder,
    this.listenWhen,
    this.buildWhen,
  });

  @override
  State<StateMachineSelectorConsumer<TContext, TEvent, TSelected>>
      createState() =>
          _StateMachineSelectorConsumerState<TContext, TEvent, TSelected>();
}

class _StateMachineSelectorConsumerState<TContext, TEvent extends XEvent,
        TSelected>
    extends State<StateMachineSelectorConsumer<TContext, TEvent, TSelected>> {
  @override
  Widget build(BuildContext context) {
    return StateMachineValueListener<TContext, TEvent, TSelected>(
      selector: widget.selector,
      listener: widget.listener,
      child: StateMachineBuilder<TContext, TEvent>(
        buildWhen: widget.buildWhen != null
            ? (previous, current) => widget.buildWhen!(
                  widget.selector(previous.context),
                  widget.selector(current.context),
                )
            : null,
        builder: (context, state, send) {
          return widget.builder(
            context,
            state,
            widget.selector(state.context),
            send,
          );
        },
      ),
    );
  }
}

/// Consumer specifically for state matching.
///
/// Provides both listener and builder callbacks that are triggered
/// when entering or exiting a specific state.
///
/// Example:
/// ```dart
/// StateMachineMatchConsumer<CheckoutContext, CheckoutEvent>(
///   stateId: 'payment',
///   onEnter: (context, state) {
///     analytics.trackPaymentStarted();
///   },
///   onExit: (context, state) {
///     analytics.trackPaymentCompleted();
///   },
///   matchBuilder: (context, state, send) {
///     return PaymentForm(onSubmit: () => send(SubmitPaymentEvent()));
///   },
///   orElse: (context, state, send) => SizedBox.shrink(),
/// )
/// ```
class StateMachineMatchConsumer<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// The state ID to match.
  final String stateId;

  /// Callback when entering the state.
  final void Function(
    BuildContext context,
    StateSnapshot<TContext> state,
  )? onEnter;

  /// Callback when exiting the state.
  final void Function(
    BuildContext context,
    StateSnapshot<TContext> state,
  )? onExit;

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

  const StateMachineMatchConsumer({
    super.key,
    required this.stateId,
    this.onEnter,
    this.onExit,
    required this.matchBuilder,
    this.orElse,
  });

  @override
  Widget build(BuildContext context) {
    return StateMachineStateListener<TContext, TEvent>(
      stateId: stateId,
      onEnter: onEnter,
      onExit: onExit,
      child: StateMachineMatchBuilder<TContext, TEvent>(
        stateId: stateId,
        matchBuilder: matchBuilder,
        orElse: orElse,
      ),
    );
  }
}

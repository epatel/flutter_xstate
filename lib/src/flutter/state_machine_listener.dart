import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';

/// Listens to state machine changes and triggers side effects.
///
/// Unlike [StateMachineBuilder], this widget does not rebuild on state changes.
/// Instead, it calls the [listener] callback for side effects like showing
/// snackbars, navigating, or logging.
///
/// Example:
/// ```dart
/// StateMachineListener<AuthContext, AuthEvent>(
///   listener: (context, state) {
///     if (state.matches('error')) {
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text(state.context.errorMessage)),
///       );
///     }
///   },
///   child: MyWidget(),
/// )
/// ```
class StateMachineListener<TContext, TEvent extends XEvent>
    extends StatefulWidget {
  /// Callback triggered on state changes.
  ///
  /// This is called after the state has changed but before the frame is drawn.
  /// Use this for side effects like navigation, showing dialogs, etc.
  final void Function(
    BuildContext context,
    StateSnapshot<TContext> state,
  ) listener;

  /// Optional condition to determine when to call the listener.
  ///
  /// If provided, the listener is only called when this returns true.
  final bool Function(
    StateSnapshot<TContext> previous,
    StateSnapshot<TContext> current,
  )? listenWhen;

  /// The child widget.
  final Widget child;

  const StateMachineListener({
    super.key,
    required this.listener,
    this.listenWhen,
    required this.child,
  });

  @override
  State<StateMachineListener<TContext, TEvent>> createState() =>
      _StateMachineListenerState<TContext, TEvent>();
}

class _StateMachineListenerState<TContext, TEvent extends XEvent>
    extends State<StateMachineListener<TContext, TEvent>> {
  late StateMachineActor<TContext, TEvent> _actor;
  StateSnapshot<TContext>? _previousState;

  @override
  void initState() {
    super.initState();
    _actor = context.read<StateMachineActor<TContext, TEvent>>();
    _previousState = _actor.snapshot;
    _actor.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _actor.removeListener(_onStateChange);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newActor = context.read<StateMachineActor<TContext, TEvent>>();
    if (newActor != _actor) {
      _actor.removeListener(_onStateChange);
      _actor = newActor;
      _previousState = _actor.snapshot;
      _actor.addListener(_onStateChange);
    }
  }

  void _onStateChange() {
    final currentState = _actor.snapshot;
    final shouldListen = widget.listenWhen?.call(
          _previousState!,
          currentState,
        ) ??
        true;

    if (shouldListen) {
      widget.listener(context, currentState);
    }

    _previousState = currentState;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Listens for when the state machine enters a specific state.
///
/// Example:
/// ```dart
/// StateMachineStateListener<AuthContext, AuthEvent>(
///   stateId: 'authenticated',
///   onEnter: (context, state) {
///     Navigator.of(context).pushReplacementNamed('/home');
///   },
///   child: LoginPage(),
/// )
/// ```
class StateMachineStateListener<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// The state ID to listen for.
  final String stateId;

  /// Callback when the state is entered.
  final void Function(
    BuildContext context,
    StateSnapshot<TContext> state,
  )? onEnter;

  /// Callback when the state is exited.
  final void Function(
    BuildContext context,
    StateSnapshot<TContext> state,
  )? onExit;

  /// The child widget.
  final Widget child;

  const StateMachineStateListener({
    super.key,
    required this.stateId,
    this.onEnter,
    this.onExit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StateMachineListener<TContext, TEvent>(
      listenWhen: (previous, current) =>
          previous.matches(stateId) != current.matches(stateId),
      listener: (context, state) {
        if (state.matches(stateId)) {
          onEnter?.call(context, state);
        } else {
          onExit?.call(context, state);
        }
      },
      child: child,
    );
  }
}

/// Listens for when the state machine reaches a final state.
///
/// Example:
/// ```dart
/// StateMachineDoneListener<CheckoutContext, CheckoutEvent>(
///   onDone: (context, state) {
///     showDialog(
///       context: context,
///       builder: (_) => SuccessDialog(orderId: state.output),
///     );
///   },
///   child: CheckoutPage(),
/// )
/// ```
class StateMachineDoneListener<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// Callback when the machine reaches a final state.
  final void Function(
    BuildContext context,
    StateSnapshot<TContext> state,
  ) onDone;

  /// The child widget.
  final Widget child;

  const StateMachineDoneListener({
    super.key,
    required this.onDone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StateMachineListener<TContext, TEvent>(
      listenWhen: (previous, current) => !previous.done && current.done,
      listener: onDone,
      child: child,
    );
  }
}

/// Listens for context value changes.
///
/// Example:
/// ```dart
/// StateMachineValueListener<CartContext, CartEvent, int>(
///   selector: (context) => context.itemCount,
///   listener: (context, state, value) {
///     if (value > 10) {
///       showBulkDiscountToast(context);
///     }
///   },
///   child: CartPage(),
/// )
/// ```
class StateMachineValueListener<TContext, TEvent extends XEvent, TValue>
    extends StatelessWidget {
  /// Selector to extract the value from context.
  final TValue Function(TContext context) selector;

  /// Callback when the selected value changes.
  final void Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    TValue value,
  ) listener;

  /// The child widget.
  final Widget child;

  const StateMachineValueListener({
    super.key,
    required this.selector,
    required this.listener,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StateMachineListener<TContext, TEvent>(
      listenWhen: (previous, current) =>
          selector(previous.context) != selector(current.context),
      listener: (context, state) {
        listener(context, state, selector(state.context));
      },
      child: child,
    );
  }
}

/// Combines multiple listeners into one widget.
///
/// Example:
/// ```dart
/// MultiStateMachineListener(
///   listeners: [
///     StateMachineListenerItem<AuthContext, AuthEvent>(
///       listener: (context, state) => handleAuthChange(state),
///     ),
///     StateMachineListenerItem<ThemeContext, ThemeEvent>(
///       listener: (context, state) => handleThemeChange(state),
///     ),
///   ],
///   child: MyApp(),
/// )
/// ```
class MultiStateMachineListener extends StatelessWidget {
  /// The list of listeners.
  final List<Widget Function(Widget child)> listeners;

  /// The child widget.
  final Widget child;

  const MultiStateMachineListener({
    super.key,
    required this.listeners,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget current = child;
    for (final listener in listeners.reversed) {
      current = listener(current);
    }
    return current;
  }
}

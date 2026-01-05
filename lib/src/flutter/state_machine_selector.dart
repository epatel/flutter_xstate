import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';
import 'state_machine_provider.dart';

/// Selects a value from the state machine context for optimized rebuilds.
///
/// [StateMachineSelector] only rebuilds when the selected value changes,
/// making it more efficient than [StateMachineBuilder] for widgets that
/// only depend on a portion of the context.
///
/// Example:
/// ```dart
/// StateMachineSelector<CartContext, CartEvent, int>(
///   selector: (context) => context.totalItems,
///   builder: (context, totalItems, send) {
///     return Badge(
///       label: Text('$totalItems'),
///       child: Icon(Icons.shopping_cart),
///     );
///   },
/// )
/// ```
class StateMachineSelector<TContext, TEvent extends XEvent, TSelected>
    extends StatelessWidget {
  /// Function to select a value from the context.
  final TSelected Function(TContext context) selector;

  /// Builder function that receives the selected value.
  final Widget Function(
    BuildContext context,
    TSelected value,
    SendEvent<TEvent> send,
  ) builder;

  /// Optional equality check for the selected value.
  ///
  /// Defaults to `==` comparison.
  final bool Function(TSelected previous, TSelected current)? equals;

  const StateMachineSelector({
    super.key,
    required this.selector,
    required this.builder,
    this.equals,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<StateMachineActor<TContext, TEvent>, TSelected>(
      selector: (_, actor) => selector(actor.snapshot.context),
      shouldRebuild: equals != null
          ? (previous, current) => !equals!(previous, current)
          : null,
      builder: (context, value, child) {
        final actor = context.read<StateMachineActor<TContext, TEvent>>();
        return builder(context, value, actor.send);
      },
    );
  }
}

/// Selects multiple values from the state machine context.
///
/// Example:
/// ```dart
/// StateMachineSelector2<CartContext, CartEvent, int, double>(
///   selector1: (context) => context.totalItems,
///   selector2: (context) => context.totalPrice,
///   builder: (context, items, price, send) {
///     return Text('$items items - \$$price');
///   },
/// )
/// ```
class StateMachineSelector2<TContext, TEvent extends XEvent, T1, T2>
    extends StatelessWidget {
  /// First selector function.
  final T1 Function(TContext context) selector1;

  /// Second selector function.
  final T2 Function(TContext context) selector2;

  /// Builder function that receives both selected values.
  final Widget Function(
    BuildContext context,
    T1 value1,
    T2 value2,
    SendEvent<TEvent> send,
  ) builder;

  const StateMachineSelector2({
    super.key,
    required this.selector1,
    required this.selector2,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<StateMachineActor<TContext, TEvent>, (T1, T2)>(
      selector: (_, actor) {
        final ctx = actor.snapshot.context;
        return (selector1(ctx), selector2(ctx));
      },
      builder: (context, values, child) {
        final actor = context.read<StateMachineActor<TContext, TEvent>>();
        return builder(context, values.$1, values.$2, actor.send);
      },
    );
  }
}

/// Selects three values from the state machine context.
class StateMachineSelector3<TContext, TEvent extends XEvent, T1, T2, T3>
    extends StatelessWidget {
  final T1 Function(TContext context) selector1;
  final T2 Function(TContext context) selector2;
  final T3 Function(TContext context) selector3;

  final Widget Function(
    BuildContext context,
    T1 value1,
    T2 value2,
    T3 value3,
    SendEvent<TEvent> send,
  ) builder;

  const StateMachineSelector3({
    super.key,
    required this.selector1,
    required this.selector2,
    required this.selector3,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<StateMachineActor<TContext, TEvent>, (T1, T2, T3)>(
      selector: (_, actor) {
        final ctx = actor.snapshot.context;
        return (selector1(ctx), selector2(ctx), selector3(ctx));
      },
      builder: (context, values, child) {
        final actor = context.read<StateMachineActor<TContext, TEvent>>();
        return builder(context, values.$1, values.$2, values.$3, actor.send);
      },
    );
  }
}

/// Selects a value and also provides access to the full state.
///
/// Useful when you need both optimized rebuilds and occasional
/// access to the full state.
///
/// Example:
/// ```dart
/// StateMachineSelectorWithState<CartContext, CartEvent, int>(
///   selector: (context) => context.totalItems,
///   builder: (context, state, totalItems, send) {
///     return Column(
///       children: [
///         Text('$totalItems items'),
///         if (state.matches('checkout'))
///           CheckoutButton(onTap: () => send(SubmitEvent())),
///       ],
///     );
///   },
/// )
/// ```
class StateMachineSelectorWithState<TContext, TEvent extends XEvent, TSelected>
    extends StatelessWidget {
  /// Function to select a value from the context.
  final TSelected Function(TContext context) selector;

  /// Builder function that receives both the state and selected value.
  final Widget Function(
    BuildContext context,
    StateSnapshot<TContext> state,
    TSelected value,
    SendEvent<TEvent> send,
  ) builder;

  /// Whether to also rebuild when the state value changes.
  ///
  /// If true, rebuilds when either the selected value or state changes.
  /// If false (default), only rebuilds when the selected value changes.
  final bool rebuildOnStateChange;

  const StateMachineSelectorWithState({
    super.key,
    required this.selector,
    required this.builder,
    this.rebuildOnStateChange = false,
  });

  @override
  Widget build(BuildContext context) {
    if (rebuildOnStateChange) {
      return Selector<StateMachineActor<TContext, TEvent>,
          (StateSnapshot<TContext>, TSelected)>(
        selector: (_, actor) =>
            (actor.snapshot, selector(actor.snapshot.context)),
        builder: (context, values, child) {
          final actor = context.read<StateMachineActor<TContext, TEvent>>();
          return builder(context, values.$1, values.$2, actor.send);
        },
      );
    }

    return Selector<StateMachineActor<TContext, TEvent>, TSelected>(
      selector: (_, actor) => selector(actor.snapshot.context),
      builder: (context, value, child) {
        final actor = context.read<StateMachineActor<TContext, TEvent>>();
        return builder(context, actor.snapshot, value, actor.send);
      },
    );
  }
}

/// Selects whether a state matches for optimized conditional rendering.
///
/// Example:
/// ```dart
/// StateMachineMatchSelector<AuthContext, AuthEvent>(
///   stateId: 'loading',
///   matchBuilder: (context, send) => CircularProgressIndicator(),
///   orElse: (context, send) => LoginForm(),
/// )
/// ```
class StateMachineMatchSelector<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// The state ID to match.
  final String stateId;

  /// Builder when the state matches.
  final Widget Function(BuildContext context, SendEvent<TEvent> send)
      matchBuilder;

  /// Builder when the state does not match.
  final Widget Function(BuildContext context, SendEvent<TEvent> send)? orElse;

  const StateMachineMatchSelector({
    super.key,
    required this.stateId,
    required this.matchBuilder,
    this.orElse,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<StateMachineActor<TContext, TEvent>, bool>(
      selector: (_, actor) => actor.matches(stateId),
      builder: (context, matches, child) {
        final actor = context.read<StateMachineActor<TContext, TEvent>>();
        if (matches) {
          return matchBuilder(context, actor.send);
        }
        return orElse?.call(context, actor.send) ?? const SizedBox.shrink();
      },
    );
  }
}

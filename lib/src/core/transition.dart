import 'package:meta/meta.dart';

import '../events/x_event.dart';
import 'state_value.dart';

/// Callback type for actions executed during transitions.
typedef ActionCallback<TContext, TEvent extends XEvent> =
    TContext Function(TContext context, TEvent event);

/// Callback type for guard conditions.
typedef GuardCallback<TContext, TEvent extends XEvent> =
    bool Function(TContext context, TEvent event);

/// Defines a transition from one state to another.
///
/// Transitions are triggered by events and can optionally:
/// - Have a [guard] condition that must be true
/// - Execute [actions] that update context
/// - Target a specific state ([target])
///
/// Example:
/// ```dart
/// final transition = Transition<MyContext, MyEvent>(
///   target: 'active',
///   guard: (ctx, event) => ctx.isValid,
///   actions: [(ctx, event) => ctx.copyWith(count: ctx.count + 1)],
/// );
/// ```
@immutable
class Transition<TContext, TEvent extends XEvent> {
  /// The target state ID to transition to.
  ///
  /// If null, this is a self-transition (stays in current state).
  final String? target;

  /// List of actions to execute during the transition.
  ///
  /// Actions are functions that take context and event,
  /// and return updated context.
  final List<ActionCallback<TContext, TEvent>> actions;

  /// Optional guard condition for this transition.
  ///
  /// If provided and returns false, the transition is not taken.
  final GuardCallback<TContext, TEvent>? guard;

  /// Human-readable description of this transition.
  final String? description;

  /// Whether this is an internal transition (no exit/entry actions).
  final bool internal;

  const Transition({
    this.target,
    this.actions = const [],
    this.guard,
    this.description,
    this.internal = false,
  });

  /// Check if the guard condition allows this transition.
  bool isEnabled(TContext context, TEvent event) {
    return guard?.call(context, event) ?? true;
  }

  /// Execute all actions and return the updated context.
  TContext executeActions(TContext context, TEvent event) {
    var currentContext = context;
    for (final action in actions) {
      currentContext = action(currentContext, event);
    }
    return currentContext;
  }

  @override
  String toString() {
    final buffer = StringBuffer('Transition(');
    if (target != null) buffer.write('target: $target');
    if (guard != null) buffer.write(', guarded');
    if (actions.isNotEmpty) buffer.write(', ${actions.length} actions');
    buffer.write(')');
    return buffer.toString();
  }
}

/// The result of resolving and executing a transition.
@immutable
class TransitionResult<TContext> {
  /// The source state value before the transition.
  final StateValue fromValue;

  /// The target state value after the transition.
  final StateValue toValue;

  /// The updated context after executing actions.
  final TContext context;

  /// Whether a transition actually occurred.
  final bool changed;

  /// History values to record (for compound states being exited).
  final Map<String, StateValue> historyUpdates;

  const TransitionResult({
    required this.fromValue,
    required this.toValue,
    required this.context,
    required this.changed,
    this.historyUpdates = const {},
  });

  /// Create a result indicating no transition occurred.
  const TransitionResult.noChange({
    required this.fromValue,
    required this.context,
  }) : toValue = fromValue,
       changed = false,
       historyUpdates = const {};

  @override
  String toString() {
    if (!changed) return 'TransitionResult(no change)';
    return 'TransitionResult($fromValue -> $toValue)';
  }
}

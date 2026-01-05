import 'package:meta/meta.dart';

import '../events/x_event.dart';
import 'state_value.dart';

/// An immutable snapshot of the state machine's current state.
///
/// Contains the current [value] (state identifier), [context] (data),
/// and metadata about the transition that led to this state.
///
/// Example:
/// ```dart
/// final snapshot = StateSnapshot<CounterContext>(
///   value: AtomicStateValue('active'),
///   context: CounterContext(count: 5),
/// );
///
/// if (snapshot.matches('active')) {
///   print('Count: ${snapshot.context.count}');
/// }
/// ```
@immutable
class StateSnapshot<TContext> {
  /// The current state value.
  final StateValue value;

  /// The current context (data) associated with the machine.
  final TContext context;

  /// The event that triggered the transition to this state, if any.
  final XEvent? event;

  /// Whether the machine has reached a final state.
  final bool done;

  /// The output from the final state, if the machine is done.
  final Object? output;

  /// History values for states that have history.
  /// Maps state path to the previously active child state.
  final Map<String, StateValue> historyValue;

  const StateSnapshot({
    required this.value,
    required this.context,
    this.event,
    this.done = false,
    this.output,
    this.historyValue = const {},
  });

  /// Check if the machine is currently in a state matching [stateId].
  ///
  /// Supports dot notation for nested states: 'parent.child'.
  ///
  /// Example:
  /// ```dart
  /// if (snapshot.matches('loading')) {
  ///   showSpinner();
  /// } else if (snapshot.matches('error.network')) {
  ///   showNetworkError();
  /// }
  /// ```
  bool matches(String stateId) => value.matches(stateId);

  /// Get all currently active state IDs.
  ///
  /// For compound states, includes both parent and child states.
  /// For parallel states, includes all active regions.
  List<String> get activeStates => value.activeStates;

  /// Check if the machine can accept more events.
  ///
  /// Returns false if the machine is in a final state.
  bool get canTransition => !done;

  /// Create a new snapshot with updated values.
  ///
  /// Only the provided parameters are changed; others retain
  /// their current values.
  StateSnapshot<TContext> copyWith({
    StateValue? value,
    TContext? context,
    XEvent? event,
    bool? done,
    Object? output,
    Map<String, StateValue>? historyValue,
  }) {
    return StateSnapshot<TContext>(
      value: value ?? this.value,
      context: context ?? this.context,
      event: event ?? this.event,
      done: done ?? this.done,
      output: output ?? this.output,
      historyValue: historyValue ?? this.historyValue,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StateSnapshot<TContext>) return false;
    return value == other.value &&
        context == other.context &&
        event == other.event &&
        done == other.done &&
        output == other.output;
  }

  @override
  int get hashCode => Object.hash(value, context, event, done, output);

  @override
  String toString() {
    final buffer = StringBuffer('StateSnapshot(');
    buffer.write('value: $value');
    buffer.write(', context: $context');
    if (done) buffer.write(', done: true');
    if (output != null) buffer.write(', output: $output');
    buffer.write(')');
    return buffer.toString();
  }
}

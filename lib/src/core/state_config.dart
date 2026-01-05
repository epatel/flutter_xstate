import 'package:meta/meta.dart';

import '../actors/invoke_config.dart';
import '../events/x_event.dart';
import 'transition.dart';

/// The type of a state node.
enum StateType {
  /// A simple leaf state with no children.
  atomic,

  /// A state with nested child states (one active at a time).
  compound,

  /// A state with parallel regions (all active simultaneously).
  parallel,

  /// A final state that indicates completion.
  final_,

  /// A pseudo-state that remembers the last active child.
  history,
}

/// Configuration for a single state in the state machine.
///
/// States can be:
/// - [StateType.atomic] - simple states with no children
/// - [StateType.compound] - nested states with one active child
/// - [StateType.parallel] - parallel regions all active
/// - [StateType.final_] - terminal states
/// - [StateType.history] - pseudo-states for history
@immutable
class StateConfig<TContext, TEvent extends XEvent> {
  /// Unique identifier for this state.
  final String id;

  /// The type of this state.
  final StateType type;

  /// For compound states, the ID of the initial child state.
  final String? initial;

  /// Child state configurations, keyed by state ID.
  final Map<String, StateConfig<TContext, TEvent>> states;

  /// Transitions keyed by event type.
  ///
  /// Multiple transitions can be defined for the same event type
  /// (first matching guard wins).
  final Map<Type, List<Transition<TContext, TEvent>>> on;

  /// Actions to execute when entering this state.
  final List<ActionCallback<TContext, TEvent>> entry;

  /// Actions to execute when exiting this state.
  final List<ActionCallback<TContext, TEvent>> exit;

  /// Services to invoke while this state is active.
  final List<InvokeConfig<TContext, TEvent>> invoke;

  /// Output value for final states.
  final Object? output;

  /// For history states, whether to use deep history.
  final bool deepHistory;

  /// For history states, the default target if no history exists.
  final String? historyDefault;

  const StateConfig({
    required this.id,
    this.type = StateType.atomic,
    this.initial,
    this.states = const {},
    this.on = const {},
    this.entry = const [],
    this.exit = const [],
    this.invoke = const [],
    this.output,
    this.deepHistory = false,
    this.historyDefault,
  });

  /// Whether this state has child states.
  bool get hasChildren => states.isNotEmpty;

  /// Whether this is a final state.
  bool get isFinal => type == StateType.final_;

  /// Whether this is an atomic (leaf) state.
  bool get isAtomic => type == StateType.atomic;

  /// Whether this is a compound state.
  bool get isCompound => type == StateType.compound;

  /// Whether this is a parallel state.
  bool get isParallel => type == StateType.parallel;

  /// Whether this is a history state.
  bool get isHistory => type == StateType.history;

  /// Get the initial child state config, if this is a compound state.
  StateConfig<TContext, TEvent>? get initialChild {
    if (initial == null) return null;
    return states[initial];
  }

  /// Find transitions that match the given event type.
  List<Transition<TContext, TEvent>> getTransitions(Type eventType) {
    return on[eventType] ?? [];
  }

  /// Get a child state by ID.
  StateConfig<TContext, TEvent>? getChild(String childId) {
    return states[childId];
  }

  /// Execute entry actions and return updated context.
  TContext executeEntry(TContext context, TEvent event) {
    var currentContext = context;
    for (final action in entry) {
      currentContext = action(currentContext, event);
    }
    return currentContext;
  }

  /// Execute exit actions and return updated context.
  TContext executeExit(TContext context, TEvent event) {
    var currentContext = context;
    for (final action in exit) {
      currentContext = action(currentContext, event);
    }
    return currentContext;
  }

  @override
  String toString() {
    return 'StateConfig($id, type: $type)';
  }
}

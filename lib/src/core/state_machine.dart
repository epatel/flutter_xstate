import 'package:meta/meta.dart';

import '../builder/machine_builder.dart';
import '../events/x_event.dart';
import '../hierarchy/transition_resolver.dart';
import 'state_config.dart';
import 'state_machine_actor.dart';
import 'state_snapshot.dart';
import 'state_value.dart';
import 'transition.dart';

/// A state machine definition.
///
/// State machines are pure definitions - they describe states, transitions,
/// and actions but don't execute them. To run a machine, create an actor
/// using [createActor].
///
/// Example:
/// ```dart
/// final machine = StateMachine.create<MyContext, MyEvent>(
///   (m) => m
///     ..context(MyContext())
///     ..initial('idle')
///     ..state('idle', (s) => s
///       ..on<StartEvent>('running')
///     )
///     ..state('running', (s) => s
///       ..on<StopEvent>('idle')
///     ),
///   id: 'myMachine',
/// );
///
/// final actor = machine.createActor();
/// actor.start();
/// actor.send(StartEvent());
/// ```
@immutable
class StateMachine<TContext, TEvent extends XEvent> {
  /// Unique identifier for this machine.
  final String id;

  /// The initial context value.
  final TContext initialContext;

  /// The root state configuration.
  final StateConfig<TContext, TEvent> root;

  /// Internal constructor. Use [StateMachine.create] instead.
  @internal
  const StateMachine.internal({
    required this.id,
    required this.initialContext,
    required this.root,
  });

  /// Create a state machine using the builder API.
  ///
  /// Example:
  /// ```dart
  /// final machine = StateMachine.create<CounterContext, CounterEvent>(
  ///   (m) => m
  ///     ..context(CounterContext(count: 0))
  ///     ..initial('active')
  ///     ..state('active', (s) => s
  ///       ..on<IncrementEvent>('active', actions: [
  ///         (ctx, _) => ctx.copyWith(count: ctx.count + 1),
  ///       ])
  ///     ),
  ///   id: 'counter',
  /// );
  /// ```
  static StateMachine<TContext, TEvent> create<TContext, TEvent extends XEvent>(
    void Function(MachineBuilder<TContext, TEvent>) build, {
    required String id,
  }) {
    final builder = MachineBuilder<TContext, TEvent>(id);
    build(builder);
    return builder.build();
  }

  /// Get the initial state snapshot for this machine.
  StateSnapshot<TContext> get initialState {
    final initialValue = _resolveInitialValue(root);
    return StateSnapshot<TContext>(
      value: initialValue,
      context: initialContext,
      event: const InitEvent(),
    );
  }

  /// Pure transition function.
  ///
  /// Given a current state and an event, computes the next state
  /// without any side effects.
  StateSnapshot<TContext> transition(
    StateSnapshot<TContext> state,
    TEvent event,
  ) {
    // Don't transition if already done
    if (state.done) return state;

    // Find matching transition
    final result = _findAndExecuteTransition(state, event);

    if (!result.changed) {
      return state;
    }

    // Check if target is a final state
    final targetConfig = _findStateConfig(result.toValue);
    final isDone = targetConfig?.isFinal ?? false;

    // Merge history updates
    final newHistory = Map<String, StateValue>.from(state.historyValue)
      ..addAll(result.historyUpdates);

    return state.copyWith(
      value: result.toValue,
      context: result.context,
      event: event,
      done: isDone,
      output: isDone ? targetConfig?.output : null,
      historyValue: newHistory,
    );
  }

  /// Create a running actor from this machine.
  StateMachineActor<TContext, TEvent> createActor({
    StateSnapshot<TContext>? initialSnapshot,
  }) {
    return StateMachineActor<TContext, TEvent>(
      this,
      initialSnapshot: initialSnapshot,
    );
  }

  /// Create a new machine with different initial context.
  StateMachine<TContext, TEvent> withContext(TContext context) {
    return StateMachine.internal(id: id, initialContext: context, root: root);
  }

  /// Resolve the initial state value from the root config.
  StateValue _resolveInitialValue(StateConfig<TContext, TEvent> config) {
    switch (config.type) {
      case StateType.atomic:
      case StateType.final_:
      case StateType.history:
        return AtomicStateValue(config.id);

      case StateType.compound:
        if (config.initial == null) {
          throw StateError(
            'Compound state "${config.id}" must have an initial child state',
          );
        }
        final childConfig = config.states[config.initial];
        if (childConfig == null) {
          throw StateError(
            'Initial state "${config.initial}" not found in "${config.id}"',
          );
        }
        return CompoundStateValue(config.id, _resolveInitialValue(childConfig));

      case StateType.parallel:
        final regions = <String, StateValue>{};
        for (final entry in config.states.entries) {
          regions[entry.key] = _resolveInitialValue(entry.value);
        }
        return ParallelStateValue(config.id, regions);
    }
  }

  /// Find and execute a transition for the given event.
  TransitionResult<TContext> _findAndExecuteTransition(
    StateSnapshot<TContext> state,
    TEvent event,
  ) {
    // Get the current state config(s)
    final activeConfigs = _getActiveStateConfigs(state.value, root);

    // Search from innermost to outermost for a matching transition
    for (final config in activeConfigs.reversed) {
      final transitions = config.getTransitions(event.runtimeType);

      for (final transition in transitions) {
        if (transition.isEnabled(state.context, event)) {
          // Found a matching transition
          return _executeTransition(state, event, config, transition);
        }
      }
    }

    // No matching transition found
    return TransitionResult.noChange(
      fromValue: state.value,
      context: state.context,
    );
  }

  /// Execute a transition and compute the result.
  TransitionResult<TContext> _executeTransition(
    StateSnapshot<TContext> state,
    TEvent event,
    StateConfig<TContext, TEvent> sourceConfig,
    Transition<TContext, TEvent> transition,
  ) {
    // Use the transition resolver for proper entry/exit ordering
    final resolver = TransitionResolver<TContext, TEvent>(root);
    final resolved = resolver.resolve(state, sourceConfig, transition, event);

    if (resolved == null) {
      return TransitionResult.noChange(
        fromValue: state.value,
        context: state.context,
      );
    }

    // Execute the resolved transition
    final newContext = resolver.executeTransition(
      resolved,
      state.context,
      event,
    );

    return TransitionResult(
      fromValue: state.value,
      toValue: resolved.targetValue,
      context: newContext,
      changed: true,
      historyUpdates: resolved.historyUpdates,
    );
  }

  /// Get all active state configs from outermost to innermost.
  List<StateConfig<TContext, TEvent>> _getActiveStateConfigs(
    StateValue value,
    StateConfig<TContext, TEvent> config,
  ) {
    final result = <StateConfig<TContext, TEvent>>[config];

    switch (value) {
      case AtomicStateValue():
        // Leaf state, no children to add
        break;

      case CompoundStateValue(:final child):
        // Find the child config and recurse
        final childId = _getStateId(child);
        final childConfig = config.states[childId];
        if (childConfig != null) {
          result.addAll(_getActiveStateConfigs(child, childConfig));
        }

      case ParallelStateValue(:final regions):
        // Add all active regions
        for (final entry in regions.entries) {
          final regionConfig = config.states[entry.key];
          if (regionConfig != null) {
            result.addAll(_getActiveStateConfigs(entry.value, regionConfig));
          }
        }
    }

    return result;
  }

  /// Get the immediate state ID from a state value.
  String _getStateId(StateValue value) {
    return switch (value) {
      AtomicStateValue(:final id) => id,
      CompoundStateValue(:final id) => id,
      ParallelStateValue(:final id) => id,
    };
  }

  /// Find a state config by state value.
  /// For compound states, returns the innermost (leaf) state config.
  StateConfig<TContext, TEvent>? _findStateConfig(StateValue value) {
    final id = _getInnermostStateId(value);
    return _findStateConfigById(id);
  }

  /// Get the innermost (leaf) state ID from a state value.
  String _getInnermostStateId(StateValue value) {
    return switch (value) {
      AtomicStateValue(:final id) => id,
      CompoundStateValue(:final child) => _getInnermostStateId(child),
      ParallelStateValue(:final id) =>
        id, // Parallel states don't have a single leaf
    };
  }

  /// Find a state config by ID, searching the entire tree.
  StateConfig<TContext, TEvent>? _findStateConfigById(String id) {
    return _searchStateConfig(root, id);
  }

  /// Recursively search for a state config by ID.
  StateConfig<TContext, TEvent>? _searchStateConfig(
    StateConfig<TContext, TEvent> config,
    String id,
  ) {
    if (config.id == id) return config;

    for (final child in config.states.values) {
      final found = _searchStateConfig(child, id);
      if (found != null) return found;
    }

    return null;
  }

  @override
  String toString() => 'StateMachine($id)';
}

import '../core/state_config.dart';
import '../core/state_machine.dart';
import '../events/x_event.dart';
import 'state_builder.dart';

/// Builder for creating state machines.
///
/// Provides a fluent API for defining states, transitions, and context.
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
///       ..on<DecrementEvent>('active',
///         guard: (ctx, _) => ctx.count > 0,
///         actions: [(ctx, _) => ctx.copyWith(count: ctx.count - 1)],
///       )
///     ),
///   id: 'counter',
/// );
/// ```
class MachineBuilder<TContext, TEvent extends XEvent> {
  final String _id;
  TContext? _initialContext;
  String? _initial;
  final Map<String, StateBuilder<TContext, TEvent>> _states = {};

  MachineBuilder(this._id);

  /// Set the initial context for the machine.
  ///
  /// This is the data that will be available in the machine's initial state.
  void context(TContext context) {
    _initialContext = context;
  }

  /// Set the initial state ID.
  ///
  /// This state will be entered when the machine starts.
  void initial(String stateId) {
    _initial = stateId;
  }

  /// Add a state to the machine.
  ///
  /// Use the builder callback to configure the state.
  ///
  /// Example:
  /// ```dart
  /// ..state('idle', (s) => s
  ///   ..on<StartEvent>('running')
  /// )
  /// ```
  void state(String id, void Function(StateBuilder<TContext, TEvent>) build) {
    final builder = StateBuilder<TContext, TEvent>(id);
    build(builder);
    _states[id] = builder;
  }

  /// Build the state machine.
  ///
  /// Validates the configuration and returns the machine.
  StateMachine<TContext, TEvent> build() {
    // Validate required fields
    if (_initialContext == null) {
      throw StateError('Machine "$_id" must have an initial context');
    }
    if (_initial == null) {
      throw StateError('Machine "$_id" must have an initial state');
    }
    if (_states.isEmpty) {
      throw StateError('Machine "$_id" must have at least one state');
    }
    if (!_states.containsKey(_initial)) {
      throw StateError(
        'Initial state "$_initial" not found in machine "$_id"',
      );
    }

    // Build the root state config
    final childConfigs = <String, StateConfig<TContext, TEvent>>{};
    for (final entry in _states.entries) {
      childConfigs[entry.key] = entry.value.build();
    }

    // The root is a compound state containing all top-level states
    final rootConfig = StateConfig<TContext, TEvent>(
      id: _id,
      type: StateType.compound,
      initial: _initial,
      states: childConfigs,
    );

    return StateMachine<TContext, TEvent>.internal(
      id: _id,
      initialContext: _initialContext as TContext,
      root: rootConfig,
    );
  }
}

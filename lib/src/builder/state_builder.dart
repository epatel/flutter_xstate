import '../actors/invoke_config.dart';
import '../core/state_config.dart';
import '../core/transition.dart';
import '../events/x_event.dart';

/// Builder for configuring a state.
///
/// Use this to define transitions, entry/exit actions, and child states.
///
/// Example:
/// ```dart
/// state('active', (s) => s
///   ..on<ClickEvent>('clicked')
///   ..entry([(ctx, _) => ctx.copyWith(enterCount: ctx.enterCount + 1)])
/// )
/// ```
class StateBuilder<TContext, TEvent extends XEvent> {
  final String _id;
  StateType _type = StateType.atomic;
  String? _initial;
  final Map<String, StateBuilder<TContext, TEvent>> _states = {};
  final Map<Type, List<Transition<TContext, TEvent>>> _on = {};
  final List<ActionCallback<TContext, TEvent>> _entry = [];
  final List<ActionCallback<TContext, TEvent>> _exit = [];
  final List<InvokeConfig<TContext, TEvent>> _invoke = [];
  Object? _output;
  bool _deepHistory = false;
  String? _historyDefault;

  StateBuilder(this._id);

  /// The ID of this state.
  String get id => _id;

  /// Mark this as the initial child state (for compound states).
  ///
  /// Example:
  /// ```dart
  /// state('traffic', (s) => s
  ///   ..initial('green')
  ///   ..state('green', (s) => s..on<TimerEvent>('yellow'))
  ///   ..state('yellow', (s) => s..on<TimerEvent>('red'))
  ///   ..state('red', (s) => s..on<TimerEvent>('green'))
  /// )
  /// ```
  void initial(String childId) {
    _type = StateType.compound;
    _initial = childId;
  }

  /// Mark this as a parallel state.
  ///
  /// All child states will be active simultaneously.
  void parallel() {
    _type = StateType.parallel;
  }

  /// Mark this as a final state.
  ///
  /// When the machine enters a final state, it's considered "done".
  /// Optionally provide an [output] value.
  void final_({Object? output}) {
    _type = StateType.final_;
    _output = output;
  }

  /// Mark this as a history state.
  ///
  /// History states remember the last active child state.
  /// Use [deep] for deep history (remembers nested children too).
  void history({bool deep = false, String? defaultTarget}) {
    _type = StateType.history;
    _deepHistory = deep;
    _historyDefault = defaultTarget;
  }

  /// Add a child state.
  ///
  /// Example:
  /// ```dart
  /// state('parent', (s) => s
  ///   ..initial('child1')
  ///   ..state('child1', (s) => s..on<NextEvent>('child2'))
  ///   ..state('child2', (s) => s..on<BackEvent>('child1'))
  /// )
  /// ```
  void state(String id, void Function(StateBuilder<TContext, TEvent>) build) {
    final builder = StateBuilder<TContext, TEvent>(id);
    build(builder);
    _states[id] = builder;

    // If we have children, we're at least compound (unless parallel)
    if (_type == StateType.atomic) {
      _type = StateType.compound;
    }
  }

  /// Define a transition on an event type.
  ///
  /// Example:
  /// ```dart
  /// // Simple transition
  /// ..on<ClickEvent>('clicked')
  ///
  /// // With guard
  /// ..on<ClickEvent>('clicked', guard: (ctx, e) => ctx.isEnabled)
  ///
  /// // With actions
  /// ..on<ClickEvent>('clicked', actions: [
  ///   (ctx, e) => ctx.copyWith(clickCount: ctx.clickCount + 1),
  /// ])
  ///
  /// // Self-transition (no target)
  /// ..on<TickEvent>(null, actions: [(ctx, _) => ctx.copyWith(ticks: ctx.ticks + 1)])
  /// ```
  void on<E extends TEvent>(
    String? target, {
    List<ActionCallback<TContext, TEvent>>? actions,
    GuardCallback<TContext, TEvent>? guard,
    bool internal = false,
    String? description,
  }) {
    final transition = Transition<TContext, TEvent>(
      target: target,
      actions: actions ?? [],
      guard: guard,
      internal: internal,
      description: description,
    );

    _on.putIfAbsent(E, () => []).add(transition);
  }

  /// Define multiple guarded transitions for the same event.
  ///
  /// The first transition whose guard returns true is taken.
  ///
  /// Example:
  /// ```dart
  /// ..onMultiple<SubmitEvent>([
  ///   (target: 'valid', guard: (ctx, _) => ctx.isValid, actions: null),
  ///   (target: 'invalid', guard: null, actions: null), // Default, no guard
  /// ])
  /// ```
  void onMultiple<E extends TEvent>(
    List<
            ({
              String? target,
              GuardCallback<TContext, TEvent>? guard,
              List<ActionCallback<TContext, TEvent>>? actions
            })>
        transitions,
  ) {
    for (final t in transitions) {
      final transition = Transition<TContext, TEvent>(
        target: t.target,
        actions: t.actions ?? [],
        guard: t.guard,
      );
      _on.putIfAbsent(E, () => []).add(transition);
    }
  }

  /// Add entry actions.
  ///
  /// These are executed when entering this state.
  void entry(List<ActionCallback<TContext, TEvent>> actions) {
    _entry.addAll(actions);
  }

  /// Add exit actions.
  ///
  /// These are executed when leaving this state.
  void exit(List<ActionCallback<TContext, TEvent>> actions) {
    _exit.addAll(actions);
  }

  /// Add services to invoke while this state is active.
  ///
  /// Invoked services run asynchronously and can send events back
  /// to the parent machine when they complete or emit values.
  ///
  /// Example:
  /// ```dart
  /// state('loading', (s) => s
  ///   ..invoke([
  ///     InvokeFuture(
  ///       id: 'fetchData',
  ///       src: (ctx, _) => api.fetchData(ctx.userId),
  ///     ),
  ///   ])
  ///   ..on<DoneInvokeEvent<Data>>('success', actions: [
  ///     (ctx, event) => ctx.copyWith(data: event.data),
  ///   ])
  ///   ..on<ErrorInvokeEvent>('error')
  /// )
  /// ```
  void invoke(List<InvokeConfig<TContext, TEvent>> configs) {
    _invoke.addAll(configs);
  }

  /// Build the state configuration.
  StateConfig<TContext, TEvent> build() {
    // Build child states
    final childConfigs = <String, StateConfig<TContext, TEvent>>{};
    for (final entry in _states.entries) {
      childConfigs[entry.key] = entry.value.build();
    }

    // Validate compound states have an initial
    if (_type == StateType.compound && _initial == null && _states.isNotEmpty) {
      throw StateError(
        'Compound state "$_id" with children must specify initial state',
      );
    }

    return StateConfig<TContext, TEvent>(
      id: _id,
      type: _type,
      initial: _initial,
      states: childConfigs,
      on: _on,
      entry: _entry,
      exit: _exit,
      invoke: _invoke,
      output: _output,
      deepHistory: _deepHistory,
      historyDefault: _historyDefault,
    );
  }
}

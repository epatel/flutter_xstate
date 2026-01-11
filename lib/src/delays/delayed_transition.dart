import 'dart:async';

import '../events/x_event.dart';

/// Configuration for a delayed transition.
///
/// Delayed transitions automatically fire after a specified duration
/// when the machine is in a particular state.
///
/// Example:
/// ```dart
/// StateMachine.create<Context, Event>((m) => m
///   ..state('loading', (s) => s
///     ..after(Duration(seconds: 5), 'timeout')
///   )
/// )
/// ```
class DelayedTransitionConfig<TContext, TEvent extends XEvent> {
  /// The delay before the transition fires.
  final Duration delay;

  /// The target state.
  final String target;

  /// Optional guard condition.
  final bool Function(TContext context)? guard;

  /// Optional actions to execute.
  final List<TContext Function(TContext context, TEvent event)> actions;

  /// Optional ID for cancellation.
  final String? id;

  const DelayedTransitionConfig({
    required this.delay,
    required this.target,
    this.guard,
    this.actions = const [],
    this.id,
  });
}

/// Configuration for a periodic transition (every).
///
/// Periodic transitions fire repeatedly at specified intervals
/// while the machine is in a particular state.
///
/// Example:
/// ```dart
/// StateMachine.create<Context, Event>((m) => m
///   ..state('polling', (s) => s
///     ..every(Duration(seconds: 30), (ctx) => PollEvent())
///   )
/// )
/// ```
class PeriodicTransitionConfig<TContext, TEvent extends XEvent> {
  /// The interval between events.
  final Duration interval;

  /// Factory to create the event to send.
  final TEvent Function(TContext context) eventFactory;

  /// Optional guard condition.
  final bool Function(TContext context)? guard;

  /// Optional ID for cancellation.
  final String? id;

  /// Whether to fire immediately on entry.
  final bool fireImmediately;

  const PeriodicTransitionConfig({
    required this.interval,
    required this.eventFactory,
    this.guard,
    this.id,
    this.fireImmediately = false,
  });
}

/// Event fired when a delayed transition times out.
class DelayedTransitionEvent extends XEvent {
  /// The ID of the delayed transition.
  final String? transitionId;

  /// The target state.
  final String target;

  DelayedTransitionEvent({this.transitionId, required this.target});

  @override
  String get type => 'xstate.delayed.$target';
}

/// Manages delayed and periodic transitions for a state.
class DelayedTransitionManager<TContext, TEvent extends XEvent> {
  final List<DelayedTransitionConfig<TContext, TEvent>> _delayedTransitions =
      [];
  final List<PeriodicTransitionConfig<TContext, TEvent>> _periodicTransitions =
      [];
  final Map<String, Timer> _activeTimers = {};
  final void Function(XEvent event) _sendEvent;

  DelayedTransitionManager(this._sendEvent);

  /// Add a delayed transition.
  void addDelayed(DelayedTransitionConfig<TContext, TEvent> config) {
    _delayedTransitions.add(config);
  }

  /// Add a periodic transition.
  void addPeriodic(PeriodicTransitionConfig<TContext, TEvent> config) {
    _periodicTransitions.add(config);
  }

  /// Start all delayed/periodic transitions for a state.
  void startTransitions(TContext context) {
    // Start delayed transitions
    for (final config in _delayedTransitions) {
      if (config.guard != null && !config.guard!(context)) {
        continue;
      }

      final timerId =
          config.id ??
          'delayed_${config.target}_${config.delay.inMilliseconds}';

      _activeTimers[timerId] = Timer(config.delay, () {
        _sendEvent(
          DelayedTransitionEvent(
            transitionId: config.id,
            target: config.target,
          ),
        );
      });
    }

    // Start periodic transitions
    for (final config in _periodicTransitions) {
      if (config.guard != null && !config.guard!(context)) {
        continue;
      }

      final timerId = config.id ?? 'periodic_${config.interval.inMilliseconds}';

      if (config.fireImmediately) {
        _sendEvent(config.eventFactory(context));
      }

      _activeTimers[timerId] = Timer.periodic(config.interval, (_) {
        _sendEvent(config.eventFactory(context));
      });
    }
  }

  /// Cancel a specific timer by ID.
  void cancelTimer(String id) {
    _activeTimers[id]?.cancel();
    _activeTimers.remove(id);
  }

  /// Cancel all active timers.
  void cancelAll() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }

  /// Get all active timer IDs.
  Set<String> get activeTimerIds => _activeTimers.keys.toSet();

  /// Check if a timer is active.
  bool isTimerActive(String id) => _activeTimers.containsKey(id);

  /// Dispose all timers and clear configurations.
  void dispose() {
    cancelAll();
    _delayedTransitions.clear();
    _periodicTransitions.clear();
  }
}

/// Extension to create delayed transition configurations.
extension DelayedTransitionExtension<TContext, TEvent extends XEvent>
    on Duration {
  /// Create a delayed transition configuration.
  DelayedTransitionConfig<TContext, TEvent> after(
    String target, {
    bool Function(TContext context)? guard,
    List<TContext Function(TContext context, TEvent event)> actions = const [],
    String? id,
  }) {
    return DelayedTransitionConfig<TContext, TEvent>(
      delay: this,
      target: target,
      guard: guard,
      actions: actions,
      id: id,
    );
  }
}

/// Helper function to create a delayed transition.
DelayedTransitionConfig<TContext, TEvent>
after<TContext, TEvent extends XEvent>(
  Duration delay,
  String target, {
  bool Function(TContext context)? guard,
  List<TContext Function(TContext context, TEvent event)> actions = const [],
  String? id,
}) {
  return DelayedTransitionConfig<TContext, TEvent>(
    delay: delay,
    target: target,
    guard: guard,
    actions: actions,
    id: id,
  );
}

/// Helper function to create a periodic transition.
PeriodicTransitionConfig<TContext, TEvent>
every<TContext, TEvent extends XEvent>(
  Duration interval,
  TEvent Function(TContext context) eventFactory, {
  bool Function(TContext context)? guard,
  String? id,
  bool fireImmediately = false,
}) {
  return PeriodicTransitionConfig<TContext, TEvent>(
    interval: interval,
    eventFactory: eventFactory,
    guard: guard,
    id: id,
    fireImmediately: fireImmediately,
  );
}

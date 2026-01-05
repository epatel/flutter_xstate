import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/state_machine.dart';
import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';

/// A record of a state transition.
class TransitionRecord<TContext> {
  /// The event that triggered the transition, if any.
  final XEvent? event;

  /// The state before the transition.
  final StateSnapshot<TContext> previousState;

  /// The state after the transition.
  final StateSnapshot<TContext> nextState;

  /// Timestamp when the transition occurred.
  final DateTime timestamp;

  /// Duration of the transition.
  final Duration duration;

  const TransitionRecord({
    this.event,
    required this.previousState,
    required this.nextState,
    required this.timestamp,
    required this.duration,
  });

  @override
  String toString() {
    final eventType = event?.type ?? 'unknown';
    return 'Transition: ${previousState.value} -> ${nextState.value} '
        '(event: $eventType, duration: ${duration.inMicroseconds}µs)';
  }
}

/// Configuration for the inspector.
class InspectorConfig {
  /// Maximum number of transitions to keep in history.
  final int maxHistorySize;

  /// Whether to log transitions to console.
  final bool logToConsole;

  /// Whether to capture context changes.
  final bool captureContext;

  /// Whether the inspector is enabled.
  final bool enabled;

  const InspectorConfig({
    this.maxHistorySize = 100,
    this.logToConsole = false,
    this.captureContext = true,
    this.enabled = true,
  });
}

/// Inspector for debugging state machines.
///
/// Provides visibility into state transitions, event history,
/// and state machine behavior.
///
/// Example:
/// ```dart
/// final inspector = StateMachineInspector<AuthContext, AuthEvent>(
///   config: InspectorConfig(logToConsole: true),
/// );
///
/// inspector.attach(authActor);
///
/// // Access transition history
/// for (final record in inspector.history) {
///   print(record);
/// }
/// ```
class StateMachineInspector<TContext, TEvent extends XEvent>
    extends ChangeNotifier {
  /// The configuration.
  final InspectorConfig config;

  /// The attached actor.
  StateMachineActor<TContext, TEvent>? _actor;

  /// Transition history.
  final List<TransitionRecord<TContext>> _history = [];

  /// Listeners for transitions.
  final List<void Function(TransitionRecord<TContext>)> _transitionListeners =
      [];

  /// Previous snapshot for tracking transitions.
  StateSnapshot<TContext>? _previousSnapshot;

  /// Stopwatch for measuring transition duration.
  final Stopwatch _stopwatch = Stopwatch();

  StateMachineInspector({
    this.config = const InspectorConfig(),
  });

  /// Attach to an actor.
  void attach(StateMachineActor<TContext, TEvent> actor) {
    if (!config.enabled) return;

    _actor = actor;
    _previousSnapshot = actor.snapshot;
    actor.addListener(_onStateChange);
  }

  /// Detach from the current actor.
  void detach() {
    _actor?.removeListener(_onStateChange);
    _actor = null;
    _previousSnapshot = null;
  }

  void _onStateChange() {
    if (_actor == null || _previousSnapshot == null) return;

    final currentSnapshot = _actor!.snapshot;
    final record = TransitionRecord<TContext>(
      event: currentSnapshot.event,
      previousState: _previousSnapshot!,
      nextState: currentSnapshot,
      timestamp: DateTime.now(),
      duration: _stopwatch.elapsed,
    );

    _addRecord(record);
    _previousSnapshot = currentSnapshot;

    if (config.logToConsole && kDebugMode) {
      // ignore: avoid_print
      print('[StateMachine] $record');
    }

    // Notify listeners
    for (final listener in _transitionListeners) {
      listener(record);
    }

    notifyListeners();
  }

  void _addRecord(TransitionRecord<TContext> record) {
    _history.add(record);

    // Trim history if needed
    while (_history.length > config.maxHistorySize) {
      _history.removeAt(0);
    }
  }

  /// Get the transition history.
  List<TransitionRecord<TContext>> get history =>
      List.unmodifiable(_history);

  /// Get the current state.
  StateSnapshot<TContext>? get currentState => _actor?.snapshot;

  /// Get the current state value as string.
  String? get currentStateValue => _actor?.snapshot.value.toString();

  /// Get the attached actor.
  StateMachineActor<TContext, TEvent>? get actor => _actor;

  /// Check if attached to an actor.
  bool get isAttached => _actor != null;

  /// Add a transition listener.
  void addTransitionListener(
    void Function(TransitionRecord<TContext>) listener,
  ) {
    _transitionListeners.add(listener);
  }

  /// Remove a transition listener.
  void removeTransitionListener(
    void Function(TransitionRecord<TContext>) listener,
  ) {
    _transitionListeners.remove(listener);
  }

  /// Clear the history.
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  /// Get transitions for a specific event type.
  List<TransitionRecord<TContext>> transitionsForEvent(String eventType) {
    return _history
        .where((record) => record.event?.type == eventType)
        .toList();
  }

  /// Get transitions to a specific state.
  List<TransitionRecord<TContext>> transitionsToState(String stateId) {
    return _history
        .where((record) => record.nextState.value.matches(stateId))
        .toList();
  }

  /// Get transitions from a specific state.
  List<TransitionRecord<TContext>> transitionsFromState(String stateId) {
    return _history
        .where((record) => record.previousState.value.matches(stateId))
        .toList();
  }

  /// Get the last N transitions.
  List<TransitionRecord<TContext>> lastTransitions(int count) {
    if (_history.length <= count) {
      return List.unmodifiable(_history);
    }
    return List.unmodifiable(_history.sublist(_history.length - count));
  }

  /// Get statistics about the state machine.
  InspectorStats get stats {
    final eventCounts = <String, int>{};
    final stateCounts = <String, int>{};
    Duration totalDuration = Duration.zero;

    for (final record in _history) {
      final eventType = record.event?.type ?? 'unknown';
      eventCounts[eventType] = (eventCounts[eventType] ?? 0) + 1;
      stateCounts[record.nextState.value.toString()] =
          (stateCounts[record.nextState.value.toString()] ?? 0) + 1;
      totalDuration += record.duration;
    }

    return InspectorStats(
      totalTransitions: _history.length,
      eventCounts: eventCounts,
      stateCounts: stateCounts,
      averageTransitionDuration: _history.isEmpty
          ? Duration.zero
          : Duration(
              microseconds: totalDuration.inMicroseconds ~/ _history.length),
    );
  }

  /// Generate a state diagram in Mermaid format.
  String generateMermaidDiagram() {
    final buffer = StringBuffer();
    buffer.writeln('stateDiagram-v2');

    final transitions = <String>{};

    for (final record in _history) {
      final from = record.previousState.value.toString();
      final to = record.nextState.value.toString();
      final event = record.event?.type ?? 'unknown';

      final transitionKey = '$from -> $to : $event';
      if (!transitions.contains(transitionKey)) {
        transitions.add(transitionKey);
        buffer.writeln('    $from --> $to : $event');
      }
    }

    return buffer.toString();
  }

  @override
  void dispose() {
    detach();
    _transitionListeners.clear();
    _history.clear();
    super.dispose();
  }
}

/// Statistics about state machine behavior.
class InspectorStats {
  /// Total number of transitions recorded.
  final int totalTransitions;

  /// Count of each event type.
  final Map<String, int> eventCounts;

  /// Count of times each state was entered.
  final Map<String, int> stateCounts;

  /// Average transition duration.
  final Duration averageTransitionDuration;

  const InspectorStats({
    required this.totalTransitions,
    required this.eventCounts,
    required this.stateCounts,
    required this.averageTransitionDuration,
  });

  @override
  String toString() {
    return '''
InspectorStats:
  Total transitions: $totalTransitions
  Average duration: ${averageTransitionDuration.inMicroseconds}µs
  Events: $eventCounts
  States: $stateCounts
''';
  }
}

/// Global inspector registry.
///
/// Allows access to inspectors from anywhere in the app.
class InspectorRegistry {
  static final InspectorRegistry _instance = InspectorRegistry._();
  static InspectorRegistry get instance => _instance;

  InspectorRegistry._();

  final Map<String, StateMachineInspector> _inspectors = {};

  /// Register an inspector.
  void register<TContext, TEvent extends XEvent>(
    String id,
    StateMachineInspector<TContext, TEvent> inspector,
  ) {
    _inspectors[id] = inspector;
  }

  /// Unregister an inspector.
  void unregister(String id) {
    _inspectors.remove(id);
  }

  /// Get an inspector by ID.
  StateMachineInspector<TContext, TEvent>?
      get<TContext, TEvent extends XEvent>(String id) {
    return _inspectors[id] as StateMachineInspector<TContext, TEvent>?;
  }

  /// Get all registered inspector IDs.
  Set<String> get ids => _inspectors.keys.toSet();

  /// Clear all inspectors.
  void clear() {
    for (final inspector in _inspectors.values) {
      inspector.dispose();
    }
    _inspectors.clear();
  }
}

/// Extension to easily attach an inspector to an actor.
extension InspectorExtension<TContext, TEvent extends XEvent>
    on StateMachineActor<TContext, TEvent> {
  /// Create and attach an inspector.
  StateMachineInspector<TContext, TEvent> inspect({
    InspectorConfig config = const InspectorConfig(),
    String? registryId,
  }) {
    final inspector = StateMachineInspector<TContext, TEvent>(config: config);
    inspector.attach(this);

    if (registryId != null) {
      InspectorRegistry.instance.register(registryId, inspector);
    }

    return inspector;
  }
}

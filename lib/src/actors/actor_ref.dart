import 'dart:async';

import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';

/// A reference to an actor (spawned child machine or invoked service).
///
/// [ActorRef] provides a way to:
/// - Send events to the actor
/// - Subscribe to state changes
/// - Stop the actor
///
/// Actor references are obtained through spawning child machines or
/// invoking services.
abstract class ActorRef<TEvent extends XEvent> {
  /// Unique identifier for this actor.
  String get id;

  /// Send an event to this actor.
  void send(TEvent event);

  /// Stop this actor.
  void stop();

  /// Whether this actor is running.
  bool get isRunning;

  /// Subscribe to this actor's lifecycle events.
  Stream<ActorStatus> get status;
}

/// Status of an actor's lifecycle.
enum ActorStatus {
  /// Actor is starting up.
  starting,

  /// Actor is running and accepting events.
  running,

  /// Actor is stopping.
  stopping,

  /// Actor has stopped.
  stopped,

  /// Actor completed with an error.
  error,
}

/// Reference to a spawned state machine actor.
///
/// Provides access to the child machine's state and allows
/// sending events to it.
class MachineActorRef<TContext, TEvent extends XEvent>
    implements ActorRef<TEvent> {
  @override
  final String id;

  /// The underlying state machine actor.
  final StateMachineActor<TContext, TEvent> actor;

  final StreamController<ActorStatus> _statusController =
      StreamController<ActorStatus>.broadcast();

  bool _stopped = false;

  MachineActorRef({required this.id, required this.actor}) {
    // Forward actor lifecycle to status stream
    actor.addListener(_onActorChange);
  }

  void _onActorChange() {
    if (actor.done) {
      _statusController.add(ActorStatus.stopped);
    }
  }

  @override
  void send(TEvent event) {
    if (_stopped) return;
    actor.send(event);
  }

  @override
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _statusController.add(ActorStatus.stopping);
    actor.stop();
    actor.removeListener(_onActorChange);
    _statusController.add(ActorStatus.stopped);
    _statusController.close();
  }

  @override
  bool get isRunning => !_stopped && actor.started && !actor.stopped;

  @override
  Stream<ActorStatus> get status => _statusController.stream;

  /// The current state snapshot of the child machine.
  StateSnapshot<TContext> get snapshot => actor.snapshot;

  /// Stream of state changes from the child machine.
  Stream<StateSnapshot<TContext>> get states => actor.stream;

  /// Check if the child machine is in a state matching the given ID.
  bool matches(String stateId) => actor.matches(stateId);

  /// Dispose resources.
  void dispose() {
    stop();
    actor.dispose();
  }
}

/// Reference to a callback-based actor (e.g., Promise/Future or Observable/Stream).
///
/// This provides a unified interface for actors that aren't state machines.
class CallbackActorRef<TData, TEvent extends XEvent>
    implements ActorRef<TEvent> {
  @override
  final String id;

  final StreamController<ActorStatus> _statusController =
      StreamController<ActorStatus>.broadcast();

  final void Function(TEvent event)? _onReceive;
  final void Function()? _onStop;

  bool _stopped = false;

  CallbackActorRef({
    required this.id,
    void Function(TEvent event)? onReceive,
    void Function()? onStop,
  }) : _onReceive = onReceive,
       _onStop = onStop {
    _statusController.add(ActorStatus.running);
  }

  @override
  void send(TEvent event) {
    if (_stopped) return;
    _onReceive?.call(event);
  }

  @override
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _statusController.add(ActorStatus.stopping);
    _onStop?.call();
    _statusController.add(ActorStatus.stopped);
    _statusController.close();
  }

  @override
  bool get isRunning => !_stopped;

  @override
  Stream<ActorStatus> get status => _statusController.stream;

  /// Signal that the actor completed successfully.
  void complete(TData data) {
    if (_stopped) return;
    _statusController.add(ActorStatus.stopped);
    stop();
  }

  /// Signal that the actor completed with an error.
  void error(Object error, [StackTrace? stackTrace]) {
    if (_stopped) return;
    _statusController.add(ActorStatus.error);
    stop();
  }
}

/// Typed event callback for sending events to a parent.
typedef SendToParent<TEvent extends XEvent> = void Function(TEvent event);

/// Typed callback for receiving events from parent.
typedef ReceiveFromParent<TEvent extends XEvent> = void Function(TEvent event);

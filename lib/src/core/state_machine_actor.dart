import 'dart:async';

import 'package:flutter/foundation.dart';

import '../actors/actor_ref.dart';
import '../actors/actor_system.dart';
import '../actors/invoke_config.dart';
import '../events/x_event.dart';
import 'state_machine.dart';
import 'state_snapshot.dart';
import 'state_value.dart';

/// A running instance of a state machine.
///
/// The actor manages the lifecycle of a state machine: starting, sending events,
/// and stopping. It extends [ChangeNotifier] for easy integration with Flutter's
/// Provider package.
///
/// Example:
/// ```dart
/// final machine = StateMachine.create<MyContext, MyEvent>(...);
/// final actor = machine.createActor();
///
/// // Listen to state changes
/// actor.addListener(() {
///   print('New state: ${actor.snapshot.value}');
/// });
///
/// // Start the machine
/// actor.start();
///
/// // Send events
/// actor.send(MyEvent());
///
/// // Stop and dispose
/// actor.dispose();
/// ```
class StateMachineActor<TContext, TEvent extends XEvent> extends ChangeNotifier
    implements ValueListenable<StateSnapshot<TContext>> {
  /// The state machine definition.
  final StateMachine<TContext, TEvent> machine;

  /// The current state snapshot.
  StateSnapshot<TContext> _snapshot;

  /// Whether the actor has been started.
  bool _started = false;

  /// Whether the actor has been stopped.
  bool _stopped = false;

  /// Stream controller for state changes.
  final StreamController<StateSnapshot<TContext>> _streamController =
      StreamController<StateSnapshot<TContext>>.broadcast();

  /// Actor system for managing child actors.
  ActorSystem? _actorSystem;

  /// Active invocations keyed by invoke ID.
  final Map<String, _ActiveInvocation> _activeInvocations = {};

  /// This actor's ID in the system (if spawned through a system).
  final String? actorId;

  /// Create an actor for the given machine.
  ///
  /// Optionally provide an [initialSnapshot] to restore state.
  StateMachineActor(
    this.machine, {
    StateSnapshot<TContext>? initialSnapshot,
    ActorSystem? actorSystem,
    this.actorId,
  }) : _snapshot = initialSnapshot ?? machine.initialState,
       _actorSystem = actorSystem;

  /// The actor system this actor belongs to.
  ActorSystem? get actorSystem => _actorSystem;

  /// The current state snapshot.
  StateSnapshot<TContext> get snapshot => _snapshot;

  /// The current state value.
  StateValue get stateValue => _snapshot.value;

  /// The current context.
  TContext get context => _snapshot.context;

  /// Whether the machine is in a final state.
  bool get done => _snapshot.done;

  /// Whether the actor has been started.
  bool get started => _started;

  /// Whether the actor has been stopped.
  bool get stopped => _stopped;

  /// A stream of state changes.
  ///
  /// Useful for integrating with other reactive systems.
  Stream<StateSnapshot<TContext>> get stream => _streamController.stream;

  /// ValueListenable implementation.
  @override
  StateSnapshot<TContext> get value => _snapshot;

  /// Check if the machine is in a state matching the given ID.
  ///
  /// Shortcut for `snapshot.matches(stateId)`.
  bool matches(String stateId) => _snapshot.matches(stateId);

  /// Start the actor.
  ///
  /// This must be called before sending events. Entry actions for the
  /// initial state are executed when starting.
  void start() {
    if (_stopped) {
      throw StateError('Cannot start a stopped actor');
    }
    if (_started) {
      debugPrint('StateMachineActor: Already started');
      return;
    }

    _started = true;

    // Execute entry actions for initial state
    _executeInitialEntry();

    // Notify listeners of initial state
    _streamController.add(_snapshot);
    notifyListeners();
  }

  /// Send an event to the machine.
  ///
  /// The event triggers a transition if one is defined for the current
  /// state. If no transition matches, the event is ignored.
  ///
  /// Does nothing if the actor is not started or already stopped.
  void send(TEvent event) {
    if (!_started) {
      debugPrint('StateMachineActor: Cannot send event before starting');
      return;
    }
    if (_stopped) {
      debugPrint('StateMachineActor: Cannot send event to stopped actor');
      return;
    }
    if (done) {
      debugPrint('StateMachineActor: Machine is in final state');
      return;
    }

    final nextSnapshot = machine.transition(_snapshot, event);

    if (nextSnapshot != _snapshot) {
      _snapshot = nextSnapshot;
      _streamController.add(_snapshot);
      notifyListeners();
    }
  }

  /// Stop the actor.
  ///
  /// After stopping, no more events can be sent. The actor can still
  /// be listened to but won't produce new states.
  void stop() {
    if (_stopped) return;

    _stopped = true;

    // Execute exit actions for current state would go here
    // For now, we just mark as stopped
  }

  /// Execute entry actions for the initial state.
  void _executeInitialEntry() {
    // Entry actions are executed during transition in the machine
    // For the initial state, we need to trigger them manually
    // This will be enhanced in Phase 2 with proper action support

    // Start invocations for initial state
    _startInvocationsForState(_snapshot.value);
  }

  /// Start invocations for states that are becoming active.
  void _startInvocationsForState(StateValue value) {
    final configs = _getActiveStateConfigs(value);
    for (final config in configs) {
      for (final invokeConfig in config.invoke) {
        _startInvocation(invokeConfig);
      }
    }
  }

  /// Get active state configs for a state value.
  List<dynamic> _getActiveStateConfigs(StateValue value) {
    // Delegate to machine's internal method via reflection or simplify
    // For now, just get the leaf state config
    return [machine.root];
  }

  /// Start an invocation.
  void _startInvocation(InvokeConfig<TContext, TEvent> config) {
    if (_activeInvocations.containsKey(config.id)) {
      return; // Already running
    }

    final result = config.invoke(_snapshot.context, _snapshot.event as TEvent);

    if (result is FutureInvokeResult<TContext, TEvent, dynamic>) {
      final futureResult = result;
      final id = futureResult.id;
      final future = futureResult.future;
      final invocation = _ActiveInvocation(id: id);
      _activeInvocations[id] = invocation;

      future
          .then((data) {
            if (!_stopped && _activeInvocations.containsKey(id)) {
              _sendInvokeEvent(
                DoneInvokeEvent<dynamic>(invokeId: id, data: data),
              );
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (!_stopped && _activeInvocations.containsKey(id)) {
              _sendInvokeEvent(
                ErrorInvokeEvent(
                  invokeId: id,
                  error: error,
                  stackTrace: stackTrace,
                ),
              );
            }
          });
    } else if (result is StreamInvokeResult<TContext, TEvent, dynamic>) {
      final streamResult = result;
      final id = streamResult.id;
      final stream = streamResult.stream;
      final subscription = stream.listen(
        (data) {
          if (!_stopped && _activeInvocations.containsKey(id)) {
            _sendInvokeEvent(
              DoneInvokeEvent<dynamic>(invokeId: id, data: data),
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!_stopped && _activeInvocations.containsKey(id)) {
            _sendInvokeEvent(
              ErrorInvokeEvent(
                invokeId: id,
                error: error,
                stackTrace: stackTrace,
              ),
            );
          }
        },
        onDone: () {
          _activeInvocations.remove(id);
        },
      );
      _activeInvocations[id] = _ActiveInvocation(
        id: id,
        subscription: subscription,
      );
    } else if (result
        is MachineInvokeResult<TContext, TEvent, dynamic, XEvent>) {
      final machineResult = result;
      final id = machineResult.id;
      final childMachine = machineResult.machine;
      _actorSystem ??= ActorSystem();
      final ref = _actorSystem!.spawn(
        id: id,
        machine: childMachine,
        parentId: actorId,
      );
      _activeInvocations[id] = _ActiveInvocation(id: id, machineRef: ref);

      // Listen for child machine completion
      ref.actor.addListener(() {
        if (ref.actor.done && !_stopped) {
          _sendInvokeEvent(
            DoneInvokeEvent<dynamic>(
              invokeId: id,
              data: ref.actor.snapshot.output,
            ),
          );
        }
      });
    } else if (result is CallbackInvokeResult<TContext, TEvent>) {
      final callbackResult = result;
      final id = callbackResult.id;
      final factory = callbackResult.factory;
      void Function(TEvent)? storedHandler;
      final cleanup = factory(
        (event) {
          if (!_stopped) send(event);
        },
        (handler) {
          storedHandler = handler;
        },
      );
      _activeInvocations[id] = _ActiveInvocation(id: id, cleanup: cleanup);
      if (storedHandler != null) {
        _activeInvocations[id]!.receiveHandler = (e) =>
            storedHandler!(e as TEvent);
      }
    }
  }

  /// Helper to send invoke events with proper type casting.
  void _sendInvokeEvent(XEvent event) {
    // Try to send as TEvent, but invoke events may not be in the event hierarchy
    try {
      send(event as TEvent);
    } catch (e) {
      // Event type doesn't match, this is expected for machines that don't
      // have DoneInvokeEvent/ErrorInvokeEvent in their event hierarchy
      debugPrint('StateMachineActor: Could not send invoke event: $event');
    }
  }

  /// Stop an invocation.
  void _stopInvocation(String id) {
    final invocation = _activeInvocations.remove(id);
    if (invocation == null) return;

    invocation.subscription?.cancel();
    invocation.machineRef?.stop();
    invocation.cleanup?.call();
  }

  /// Stop all active invocations.
  void _stopAllInvocations() {
    final ids = _activeInvocations.keys.toList();
    for (final id in ids) {
      _stopInvocation(id);
    }
  }

  /// Send an event to a child actor.
  void sendToChild(String childId, XEvent event) {
    final invocation = _activeInvocations[childId];
    if (invocation?.machineRef != null) {
      invocation!.machineRef!.send(event);
    } else if (invocation?.receiveHandler != null) {
      invocation!.receiveHandler!(event as TEvent);
    }
  }

  /// Get a child actor reference by ID.
  ActorRef<XEvent>? getChild(String childId) {
    return _activeInvocations[childId]?.machineRef;
  }

  @override
  void dispose() {
    stop();
    _stopAllInvocations();
    _streamController.close();
    super.dispose();
  }

  @override
  String toString() {
    return 'StateMachineActor(${machine.id}, state: ${_snapshot.value})';
  }
}

/// Extension to create a stream from a StateMachineActor.
extension StateMachineActorStream<TContext, TEvent extends XEvent>
    on StateMachineActor<TContext, TEvent> {
  /// Convert state changes to a stream.
  ///
  /// The stream includes the current state immediately, then all
  /// subsequent state changes.
  Stream<StateSnapshot<TContext>> asStream() async* {
    yield snapshot;
    yield* stream;
  }
}

/// Internal class to track active invocations.
class _ActiveInvocation {
  final String id;
  final StreamSubscription<dynamic>? subscription;
  final MachineActorRef<dynamic, XEvent>? machineRef;
  final void Function()? cleanup;
  void Function(XEvent event)? receiveHandler;

  _ActiveInvocation({
    required this.id,
    this.subscription,
    this.machineRef,
    this.cleanup,
  });
}

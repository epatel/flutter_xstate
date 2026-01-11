import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/state_machine.dart';
import '../core/state_machine_actor.dart';
import '../events/x_event.dart';
import 'actor_ref.dart';

/// A system for managing actors (spawned machines and invoked services).
///
/// The [ActorSystem] provides:
/// - Actor registration and lookup by ID
/// - Automatic cleanup when actors stop
/// - Parent-child relationship tracking
/// - Event routing between actors
///
/// Example:
/// ```dart
/// final system = ActorSystem();
///
/// // Spawn a child actor
/// final childRef = system.spawn(
///   id: 'child',
///   machine: childMachine,
/// );
///
/// // Send event to child
/// childRef.send(SomeEvent());
///
/// // Get actor by ID
/// final ref = system.getActor<ChildEvent>('child');
///
/// // Stop all actors
/// system.dispose();
/// ```
class ActorSystem extends ChangeNotifier {
  /// All registered actors by ID.
  final Map<String, ActorRef<XEvent>> _actors = {};

  /// Parent-child relationships.
  final Map<String, Set<String>> _children = {};

  /// Child-parent relationships.
  final Map<String, String> _parents = {};

  /// Subscriptions for actor status changes.
  final Map<String, StreamSubscription<ActorStatus>> _statusSubscriptions = {};

  /// Get all registered actor IDs.
  Set<String> get actorIds => _actors.keys.toSet();

  /// Get the number of registered actors.
  int get actorCount => _actors.length;

  /// Check if an actor with the given ID exists.
  bool hasActor(String id) => _actors.containsKey(id);

  /// Get an actor by ID.
  ///
  /// Returns null if no actor with the given ID exists.
  ActorRef<TEvent>? getActor<TEvent extends XEvent>(String id) {
    final actor = _actors[id];
    if (actor == null) return null;
    return actor as ActorRef<TEvent>;
  }

  /// Get all child actor IDs for a parent.
  Set<String> getChildren(String parentId) {
    return _children[parentId] ?? const {};
  }

  /// Get the parent actor ID for a child.
  String? getParent(String childId) => _parents[childId];

  /// Spawn a new state machine actor.
  ///
  /// Returns a [MachineActorRef] that can be used to interact with the
  /// spawned actor.
  ///
  /// If [parentId] is provided, the spawned actor is registered as a child
  /// of that parent.
  MachineActorRef<TContext, TEvent> spawn<TContext, TEvent extends XEvent>({
    required String id,
    required StateMachine<TContext, TEvent> machine,
    String? parentId,
    bool autoStart = true,
  }) {
    if (_actors.containsKey(id)) {
      throw StateError('Actor with id "$id" already exists');
    }

    final actor = machine.createActor();
    final ref = MachineActorRef<TContext, TEvent>(id: id, actor: actor);

    _registerActor(id, ref, parentId);

    if (autoStart) {
      actor.start();
    }

    return ref;
  }

  /// Register a callback-based actor (for Futures/Streams).
  ///
  /// Used internally by invoke to track async operations.
  @internal
  CallbackActorRef<TData, TEvent>
  registerCallback<TData, TEvent extends XEvent>({
    required String id,
    String? parentId,
    void Function(TEvent event)? onReceive,
    void Function()? onStop,
  }) {
    if (_actors.containsKey(id)) {
      throw StateError('Actor with id "$id" already exists');
    }

    final ref = CallbackActorRef<TData, TEvent>(
      id: id,
      onReceive: onReceive,
      onStop: onStop,
    );

    _registerActor(id, ref, parentId);

    return ref;
  }

  /// Register an actor and set up parent-child relationships.
  void _registerActor<TEvent extends XEvent>(
    String id,
    ActorRef<TEvent> ref,
    String? parentId,
  ) {
    _actors[id] = ref;

    if (parentId != null) {
      _parents[id] = parentId;
      _children.putIfAbsent(parentId, () => {});
      _children[parentId]!.add(id);
    }

    // Subscribe to status changes for cleanup
    _statusSubscriptions[id] = ref.status.listen((status) {
      if (status == ActorStatus.stopped || status == ActorStatus.error) {
        _handleActorStopped(id);
      }
    });

    notifyListeners();
  }

  /// Stop an actor by ID.
  ///
  /// Also stops all child actors recursively.
  void stopActor(String id) {
    final actor = _actors[id];
    if (actor == null) return;

    // Stop children first
    final children = _children[id]?.toList() ?? [];
    for (final childId in children) {
      stopActor(childId);
    }

    actor.stop();
  }

  /// Handle an actor stopping.
  void _handleActorStopped(String id) {
    // Cancel status subscription
    _statusSubscriptions[id]?.cancel();
    _statusSubscriptions.remove(id);

    // Remove from actors
    _actors.remove(id);

    // Clean up parent-child relationships
    final parentId = _parents.remove(id);
    if (parentId != null) {
      _children[parentId]?.remove(id);
      if (_children[parentId]?.isEmpty ?? false) {
        _children.remove(parentId);
      }
    }

    // Clean up any children of this actor
    final children = _children.remove(id);
    if (children != null) {
      for (final childId in children) {
        _parents.remove(childId);
      }
    }

    notifyListeners();
  }

  /// Send an event to an actor by ID.
  ///
  /// Returns true if the event was sent, false if no actor exists.
  bool sendTo<TEvent extends XEvent>(String id, TEvent event) {
    final actor = _actors[id];
    if (actor == null) return false;

    (actor as ActorRef<TEvent>).send(event);
    return true;
  }

  /// Broadcast an event to all actors.
  void broadcast<TEvent extends XEvent>(TEvent event) {
    for (final actor in _actors.values) {
      try {
        (actor as ActorRef<TEvent>).send(event);
      } catch (_) {
        // Actor doesn't accept this event type, skip
      }
    }
  }

  /// Stop all actors and clean up resources.
  @override
  void dispose() {
    // Stop all actors (copy keys to avoid modification during iteration)
    final ids = _actors.keys.toList();
    for (final id in ids) {
      stopActor(id);
    }

    // Cancel all subscriptions
    for (final sub in _statusSubscriptions.values) {
      sub.cancel();
    }
    _statusSubscriptions.clear();

    // Clear all collections
    _actors.clear();
    _children.clear();
    _parents.clear();

    super.dispose();
  }
}

/// Extension to get actor system from a StateMachineActor.
extension ActorSystemAccess<TContext, TEvent extends XEvent>
    on StateMachineActor<TContext, TEvent> {
  /// The actor system this actor belongs to, if any.
  ///
  /// Returns null if this actor was not spawned through an [ActorSystem].
  ActorSystem? get system => _actorSystems[this];

  /// Set the actor system for this actor.
  ///
  /// Used internally when spawning actors.
  set system(ActorSystem? value) {
    if (value != null) {
      _actorSystems[this] = value;
    }
    // Note: Expando doesn't support removing entries, so setting to null
    // will not actually clear the entry, but it will return null on get
  }
}

/// Internal storage for actor system associations.
final Expando<ActorSystem> _actorSystems = Expando<ActorSystem>();

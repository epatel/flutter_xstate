import 'package:meta/meta.dart';

import '../actions/action.dart';
import '../core/state_machine.dart';
import '../events/x_event.dart';
import 'actor_ref.dart';

/// Configuration for spawning a child actor.
///
/// Used with [SpawnAction] to define how a child machine should be spawned.
@immutable
class SpawnConfig<TChildContext, TChildEvent extends XEvent> {
  /// Unique identifier for the spawned actor.
  final String id;

  /// The machine to spawn.
  final StateMachine<TChildContext, TChildEvent> machine;

  /// Whether to start the actor automatically.
  final bool autoStart;

  /// Callback to determine the id dynamically based on context and event.
  final String Function(dynamic context, dynamic event)? idFromContext;

  const SpawnConfig({
    required this.id,
    required this.machine,
    this.autoStart = true,
    this.idFromContext,
  });

  /// Create a spawn config with a dynamic id.
  const SpawnConfig.dynamic({
    required String Function(dynamic context, dynamic event) id,
    required this.machine,
    this.autoStart = true,
  }) : id = '',
       idFromContext = id;

  /// Get the actual id to use, resolving dynamic ids.
  String resolveId(dynamic context, dynamic event) {
    if (idFromContext != null) {
      return idFromContext!(context, event);
    }
    return id;
  }
}

/// An action that spawns a child actor.
///
/// When this action executes, it records the spawn configuration in the
/// action result. The actual spawning is handled by the actor that
/// executes the transition.
///
/// Example:
/// ```dart
/// state('parent', (s) => s
///   ..entry([
///     spawn(SpawnConfig(
///       id: 'child',
///       machine: childMachine,
///     )),
///   ])
/// )
/// ```
class SpawnAction<
  TContext,
  TEvent extends XEvent,
  TChildContext,
  TChildEvent extends XEvent
>
    extends Action<TContext, TEvent> {
  /// The spawn configuration.
  final SpawnConfig<TChildContext, TChildEvent> config;

  const SpawnAction(this.config);

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    // Return the context unchanged, but include spawn info in result
    return SpawnActionResult<TContext, TEvent, TChildContext, TChildEvent>(
      context: context,
      spawnConfig: config,
    );
  }

  @override
  String? get description => 'spawn(${config.id})';
}

/// Action result that includes spawn configuration.
class SpawnActionResult<
  TContext,
  TEvent extends XEvent,
  TChildContext,
  TChildEvent extends XEvent
>
    extends ActionResult<TContext, TEvent> {
  /// The spawn configuration to execute.
  final SpawnConfig<TChildContext, TChildEvent> spawnConfig;

  const SpawnActionResult({required super.context, required this.spawnConfig});

  @override
  ActionResult<TContext, TEvent> merge(ActionResult<TContext, TEvent> other) {
    final base = super.merge(other);
    // If other is also a spawn result, we need special handling
    if (other
        is SpawnActionResult<TContext, TEvent, TChildContext, TChildEvent>) {
      // Both are spawn results - would need a list, for now keep latest
      return SpawnActionResult(
        context: base.context,
        spawnConfig: other.spawnConfig,
      );
    }
    // Keep spawn config from this result
    return SpawnActionResult(context: base.context, spawnConfig: spawnConfig);
  }
}

/// Create a spawn action.
///
/// Example:
/// ```dart
/// state('parent', (s) => s
///   ..entry([
///     spawn<ParentContext, ParentEvent, ChildContext, ChildEvent>(
///       SpawnConfig(id: 'child', machine: childMachine),
///     ),
///   ])
/// )
/// ```
SpawnAction<TContext, TEvent, TChildContext, TChildEvent> spawn<
  TContext,
  TEvent extends XEvent,
  TChildContext,
  TChildEvent extends XEvent
>(SpawnConfig<TChildContext, TChildEvent> config) {
  return SpawnAction<TContext, TEvent, TChildContext, TChildEvent>(config);
}

/// An action that stops a child actor.
///
/// Example:
/// ```dart
/// state('parent', (s) => s
///   ..exit([
///     stopChild('child'),
///   ])
/// )
/// ```
class StopChildAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  /// The ID of the child actor to stop.
  final String childId;

  /// Callback to determine the id dynamically.
  final String Function(TContext context, TEvent event)? idFromContext;

  const StopChildAction(this.childId) : idFromContext = null;

  const StopChildAction.dynamic(this.idFromContext) : childId = '';

  /// Get the actual id to use.
  String resolveId(TContext context, TEvent event) {
    if (idFromContext != null) {
      return idFromContext!(context, event);
    }
    return childId;
  }

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    return StopChildActionResult<TContext, TEvent>(
      context: context,
      childId: resolveId(context, event),
    );
  }

  @override
  String? get description => 'stopChild($childId)';
}

/// Action result that includes stop child configuration.
class StopChildActionResult<TContext, TEvent extends XEvent>
    extends ActionResult<TContext, TEvent> {
  /// The ID of the child actor to stop.
  final String childId;

  const StopChildActionResult({required super.context, required this.childId});
}

/// Create an action to stop a child actor.
StopChildAction<TContext, TEvent> stopChild<TContext, TEvent extends XEvent>(
  String childId,
) {
  return StopChildAction<TContext, TEvent>(childId);
}

/// Create an action to stop a child actor with dynamic ID.
StopChildAction<TContext, TEvent> stopChildDynamic<
  TContext,
  TEvent extends XEvent
>(String Function(TContext context, TEvent event) idFromContext) {
  return StopChildAction<TContext, TEvent>.dynamic(idFromContext);
}

/// An action that sends an event to a child actor.
class SendToChildAction<
  TContext,
  TEvent extends XEvent,
  TChildEvent extends XEvent
>
    extends Action<TContext, TEvent> {
  /// The ID of the target child actor.
  final String childId;

  /// The event to send (null if using dynamic).
  final TChildEvent? _event;

  /// Callback to create the event dynamically.
  final TChildEvent Function(TContext context, TEvent event)? eventFromContext;

  const SendToChildAction({required this.childId, required TChildEvent event})
    : _event = event,
      eventFromContext = null;

  const SendToChildAction.dynamic({
    required this.childId,
    required this.eventFromContext,
  }) : _event = null;

  /// Get the actual event to send.
  TChildEvent resolveEvent(TContext context, TEvent triggerEvent) {
    if (eventFromContext != null) {
      return eventFromContext!(context, triggerEvent);
    }
    return _event!;
  }

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    return SendToChildActionResult<TContext, TEvent, TChildEvent>(
      context: context,
      childId: childId,
      childEvent: resolveEvent(context, event),
    );
  }

  @override
  String? get description => 'sendToChild($childId)';
}

/// Action result that includes send to child configuration.
class SendToChildActionResult<
  TContext,
  TEvent extends XEvent,
  TChildEvent extends XEvent
>
    extends ActionResult<TContext, TEvent> {
  /// The ID of the target child actor.
  final String childId;

  /// The event to send to the child.
  final TChildEvent childEvent;

  const SendToChildActionResult({
    required super.context,
    required this.childId,
    required this.childEvent,
  });
}

/// Create an action to send an event to a child actor.
SendToChildAction<TContext, TEvent, TChildEvent> sendToChild<
  TContext,
  TEvent extends XEvent,
  TChildEvent extends XEvent
>({required String childId, required TChildEvent event}) {
  return SendToChildAction<TContext, TEvent, TChildEvent>(
    childId: childId,
    event: event,
  );
}

/// Handler for actor lifecycle events.
///
/// Used to react when child actors complete or error.
@immutable
class ActorLifecycleHandler<
  TContext,
  TEvent extends XEvent,
  TChildContext,
  TChildEvent extends XEvent
> {
  /// Called when the child actor reaches a final state.
  final TContext Function(
    TContext context,
    MachineActorRef<TChildContext, TChildEvent> ref,
  )?
  onDone;

  /// Called when the child actor errors.
  final TContext Function(
    TContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  onError;

  const ActorLifecycleHandler({this.onDone, this.onError});
}

import 'package:meta/meta.dart';

import '../events/x_event.dart';

/// Base class for all actions in a state machine.
///
/// Actions are executed during transitions and can:
/// - Modify context (via [assign])
/// - Raise new events (via [raise])
/// - Log messages (via [log])
/// - Send events to other actors (via [sendTo])
///
/// Actions are pure functions that take context and event as input
/// and return an [ActionResult] containing the updated context and
/// any side effects to execute.
@immutable
abstract class Action<TContext, TEvent extends XEvent> {
  const Action();

  /// Execute this action and return the result.
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event);

  /// Human-readable description of this action.
  String? get description => null;
}

/// The result of executing an action.
///
/// Contains the updated context and any side effects to perform.
@immutable
class ActionResult<TContext, TEvent extends XEvent> {
  /// The updated context after the action.
  final TContext context;

  /// Events to raise after this action completes.
  final List<TEvent> raisedEvents;

  /// Messages to log.
  final List<String> logMessages;

  /// Events to send to other actors.
  final List<SendToAction<TEvent>> sendToActions;

  const ActionResult({
    required this.context,
    this.raisedEvents = const [],
    this.logMessages = const [],
    this.sendToActions = const [],
  });

  /// Create a result with just context update.
  const ActionResult.context(this.context)
    : raisedEvents = const [],
      logMessages = const [],
      sendToActions = const [];

  /// Merge this result with another, combining side effects.
  ActionResult<TContext, TEvent> merge(ActionResult<TContext, TEvent> other) {
    return ActionResult(
      context: other.context,
      raisedEvents: [...raisedEvents, ...other.raisedEvents],
      logMessages: [...logMessages, ...other.logMessages],
      sendToActions: [...sendToActions, ...other.sendToActions],
    );
  }
}

/// Represents an action to send an event to another actor.
@immutable
class SendToAction<TEvent extends XEvent> {
  /// The ID of the target actor.
  final String actorId;

  /// The event to send.
  final TEvent event;

  const SendToAction(this.actorId, this.event);
}

/// An inline action defined with a callback function.
///
/// This is the most common way to define actions:
/// ```dart
/// InlineAction<MyContext, MyEvent>((ctx, event) => ctx.copyWith(...))
/// ```
class InlineAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final TContext Function(TContext context, TEvent event) _callback;

  @override
  final String? description;

  const InlineAction(this._callback, {this.description});

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    final newContext = _callback(context, event);
    return ActionResult.context(newContext);
  }
}

/// A named action that can be referenced by name.
///
/// Named actions are defined in the machine configuration and can be
/// referenced by name in transitions. This allows for:
/// - Reusing actions across multiple transitions
/// - Overriding actions when testing
/// - Better debugging and visualization
class NamedAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  /// The name of this action.
  final String name;

  /// The actual action implementation.
  final Action<TContext, TEvent> action;

  const NamedAction(this.name, this.action);

  @override
  String? get description => name;

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    return action.execute(context, event);
  }
}

/// Extension to convert action callbacks to Action objects.
extension ActionCallbackExtension<TContext, TEvent extends XEvent>
    on TContext Function(TContext, TEvent) {
  /// Convert this callback to an [InlineAction].
  Action<TContext, TEvent> toAction({String? description}) {
    return InlineAction<TContext, TEvent>(this, description: description);
  }
}

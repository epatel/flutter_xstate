import '../events/x_event.dart';
import 'action.dart';

/// Creates an action that updates the context.
///
/// This is the primary way to modify state machine data during transitions.
///
/// Example:
/// ```dart
/// ..on<IncrementEvent>('active', actions: [
///   assign((ctx, _) => ctx.copyWith(count: ctx.count + 1)),
/// ])
/// ```
Action<TContext, TEvent> assign<TContext, TEvent extends XEvent>(
  TContext Function(TContext context, TEvent event) updater,
) {
  return AssignAction<TContext, TEvent>(updater);
}

/// An action that updates the context using an updater function.
class AssignAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final TContext Function(TContext context, TEvent event) _updater;

  const AssignAction(this._updater);

  @override
  String? get description => 'assign';

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    final newContext = _updater(context, event);
    return ActionResult.context(newContext);
  }
}

/// Creates an action that raises a new event.
///
/// The raised event will be processed after the current transition completes.
/// This is useful for triggering follow-up transitions.
///
/// Example:
/// ```dart
/// ..on<SubmitEvent>('validating', actions: [
///   raise(ValidateEvent()),
/// ])
/// ```
Action<TContext, TEvent> raise<TContext, TEvent extends XEvent>(
  TEvent event,
) {
  return RaiseAction<TContext, TEvent>(event);
}

/// Creates an action that raises an event computed from context.
///
/// Example:
/// ```dart
/// ..on<CheckEvent>('checking', actions: [
///   raiseFrom((ctx, _) => ctx.isValid ? ValidEvent() : InvalidEvent()),
/// ])
/// ```
Action<TContext, TEvent> raiseFrom<TContext, TEvent extends XEvent>(
  TEvent Function(TContext context, TEvent event) eventFactory,
) {
  return RaiseFromAction<TContext, TEvent>(eventFactory);
}

/// An action that raises a static event.
class RaiseAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final TEvent _event;

  const RaiseAction(this._event);

  @override
  String? get description => 'raise(${_event.type})';

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    return ActionResult(
      context: context,
      raisedEvents: [_event],
    );
  }
}

/// An action that raises an event computed from context.
class RaiseFromAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final TEvent Function(TContext context, TEvent event) _eventFactory;

  const RaiseFromAction(this._eventFactory);

  @override
  String? get description => 'raiseFrom';

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    final raisedEvent = _eventFactory(context, event);
    return ActionResult(
      context: context,
      raisedEvents: [raisedEvent],
    );
  }
}

/// Creates an action that logs a message.
///
/// Example:
/// ```dart
/// ..on<ErrorEvent>('error', actions: [
///   log((ctx, event) => 'Error occurred: ${event.message}'),
/// ])
/// ```
Action<TContext, TEvent> log<TContext, TEvent extends XEvent>(
  String Function(TContext context, TEvent event) messageFactory,
) {
  return LogAction<TContext, TEvent>(messageFactory);
}

/// Creates an action that logs a static message.
///
/// Example:
/// ```dart
/// ..on<StartEvent>('running', actions: [
///   logMessage('Machine started'),
/// ])
/// ```
Action<TContext, TEvent> logMessage<TContext, TEvent extends XEvent>(
  String message,
) {
  return LogAction<TContext, TEvent>((_, _) => message);
}

/// An action that logs a message.
class LogAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final String Function(TContext context, TEvent event) _messageFactory;

  const LogAction(this._messageFactory);

  @override
  String? get description => 'log';

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    final message = _messageFactory(context, event);
    return ActionResult(
      context: context,
      logMessages: [message],
    );
  }
}

/// Creates an action that sends an event to another actor.
///
/// Example:
/// ```dart
/// ..on<NotifyEvent>('notifying', actions: [
///   sendTo('parentActor', AckEvent()),
/// ])
/// ```
Action<TContext, TEvent> sendTo<TContext, TEvent extends XEvent>(
  String actorId,
  TEvent event,
) {
  return SendToActionImpl<TContext, TEvent>(actorId, event);
}

/// Creates an action that sends a computed event to another actor.
///
/// Example:
/// ```dart
/// ..on<CompleteEvent>('done', actions: [
///   sendToFrom('parent', (ctx, _) => ResultEvent(ctx.result)),
/// ])
/// ```
Action<TContext, TEvent> sendToFrom<TContext, TEvent extends XEvent>(
  String actorId,
  TEvent Function(TContext context, TEvent event) eventFactory,
) {
  return SendToFromAction<TContext, TEvent>(actorId, eventFactory);
}

/// An action that sends a static event to another actor.
class SendToActionImpl<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final String _actorId;
  final TEvent _event;

  const SendToActionImpl(this._actorId, this._event);

  @override
  String? get description => 'sendTo($_actorId, ${_event.type})';

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    return ActionResult(
      context: context,
      sendToActions: [SendToAction(_actorId, _event)],
    );
  }
}

/// An action that sends a computed event to another actor.
class SendToFromAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final String _actorId;
  final TEvent Function(TContext context, TEvent event) _eventFactory;

  const SendToFromAction(this._actorId, this._eventFactory);

  @override
  String? get description => 'sendToFrom($_actorId)';

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    final sendEvent = _eventFactory(context, event);
    return ActionResult(
      context: context,
      sendToActions: [SendToAction(_actorId, sendEvent)],
    );
  }
}

/// Creates a pure action that doesn't modify context.
///
/// Useful for side effects like logging or sending events.
///
/// Example:
/// ```dart
/// ..on<ClickEvent>('clicked', actions: [
///   pure((ctx, event) => print('Clicked: ${event.target}')),
/// ])
/// ```
Action<TContext, TEvent> pure<TContext, TEvent extends XEvent>(
  void Function(TContext context, TEvent event) sideEffect,
) {
  return PureAction<TContext, TEvent>(sideEffect);
}

/// An action that performs a side effect without modifying context.
class PureAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final void Function(TContext context, TEvent event) _sideEffect;

  const PureAction(this._sideEffect);

  @override
  String? get description => 'pure';

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    _sideEffect(context, event);
    return ActionResult.context(context);
  }
}

/// Combines multiple actions into a sequence.
///
/// Actions are executed in order, with each action receiving the
/// context from the previous action.
///
/// Example:
/// ```dart
/// ..on<SubmitEvent>('submitting', actions: [
///   sequence([
///     assign((ctx, _) => ctx.copyWith(loading: true)),
///     log((ctx, _) => 'Submitting form...'),
///   ]),
/// ])
/// ```
Action<TContext, TEvent> sequence<TContext, TEvent extends XEvent>(
  List<Action<TContext, TEvent>> actions,
) {
  return SequenceAction<TContext, TEvent>(actions);
}

/// An action that executes multiple actions in sequence.
class SequenceAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final List<Action<TContext, TEvent>> _actions;

  const SequenceAction(this._actions);

  @override
  String? get description =>
      'sequence(${_actions.map((a) => a.description).join(', ')})';

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    var result = ActionResult<TContext, TEvent>.context(context);

    for (final action in _actions) {
      final actionResult = action.execute(result.context, event);
      result = result.merge(actionResult);
    }

    return result;
  }
}

/// Creates a conditional action that only executes if a condition is met.
///
/// Example:
/// ```dart
/// ..on<IncrementEvent>('active', actions: [
///   when(
///     (ctx, _) => ctx.count < 10,
///     assign((ctx, _) => ctx.copyWith(count: ctx.count + 1)),
///   ),
/// ])
/// ```
Action<TContext, TEvent> when<TContext, TEvent extends XEvent>(
  bool Function(TContext context, TEvent event) condition,
  Action<TContext, TEvent> action,
) {
  return ConditionalAction<TContext, TEvent>(condition, action);
}

/// An action that conditionally executes another action.
class ConditionalAction<TContext, TEvent extends XEvent>
    extends Action<TContext, TEvent> {
  final bool Function(TContext context, TEvent event) _condition;
  final Action<TContext, TEvent> _action;

  const ConditionalAction(this._condition, this._action);

  @override
  String? get description => 'when(${_action.description})';

  @override
  ActionResult<TContext, TEvent> execute(TContext context, TEvent event) {
    if (_condition(context, event)) {
      return _action.execute(context, event);
    }
    return ActionResult.context(context);
  }
}

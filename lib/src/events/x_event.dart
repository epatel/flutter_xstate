/// Base class for all state machine events.
///
/// Events trigger transitions in state machines. Each event has a [type]
/// that identifies it for transition matching.
///
/// Example:
/// ```dart
/// sealed class CounterEvent extends XEvent {}
///
/// class IncrementEvent extends CounterEvent {
///   @override
///   String get type => 'INCREMENT';
/// }
/// ```
abstract class XEvent {
  const XEvent();

  /// The type identifier for this event.
  String get type;

  @override
  String toString() => 'XEvent($type)';
}

/// A simple event that only carries a type string.
///
/// Useful for events that don't need additional data.
///
/// Example:
/// ```dart
/// machine.send(SimpleEvent('TOGGLE'));
/// ```
class SimpleEvent extends XEvent {
  @override
  final String type;

  const SimpleEvent(this.type);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleEvent &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;
}

/// Internal event sent when a machine is started.
class InitEvent extends XEvent {
  const InitEvent();

  @override
  String get type => 'xstate.init';
}

/// Internal event sent when a state is done (final state reached).
class DoneStateEvent extends XEvent {
  /// The output from the final state, if any.
  final Object? output;

  const DoneStateEvent({this.output});

  @override
  String get type => 'xstate.done.state';
}

/// Internal event sent when an invoked service completes successfully.
class DoneInvokeEvent<T> extends XEvent {
  /// The ID of the invoked service.
  final String invokeId;

  /// The data returned by the service.
  final T data;

  const DoneInvokeEvent({required this.invokeId, required this.data});

  @override
  String get type => 'xstate.done.invoke.$invokeId';
}

/// Internal event sent when an invoked service fails.
class ErrorInvokeEvent extends XEvent {
  /// The ID of the invoked service.
  final String invokeId;

  /// The error that occurred.
  final Object error;

  /// The stack trace, if available.
  final StackTrace? stackTrace;

  const ErrorInvokeEvent({
    required this.invokeId,
    required this.error,
    this.stackTrace,
  });

  @override
  String get type => 'xstate.error.invoke.$invokeId';
}

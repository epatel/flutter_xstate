import 'package:meta/meta.dart';

import '../events/x_event.dart';

/// Base class for guard conditions in state machines.
///
/// Guards are predicates that determine whether a transition should be taken.
/// If a guard returns false, the transition is skipped and the next
/// matching transition is evaluated.
///
/// Example:
/// ```dart
/// ..on<DecrementEvent>('active',
///   guard: guard((ctx, _) => ctx.count > 0),
///   actions: [assign((ctx, _) => ctx.copyWith(count: ctx.count - 1))],
/// )
/// ```
@immutable
abstract class Guard<TContext, TEvent extends XEvent> {
  const Guard();

  /// Evaluate this guard condition.
  bool evaluate(TContext context, TEvent event);

  /// Human-readable description of this guard.
  String? get description => null;

  /// Convert this guard to a callback function.
  bool Function(TContext, TEvent) toCallback() {
    return (context, event) => evaluate(context, event);
  }
}

/// Creates a guard from a callback function.
///
/// This is the primary way to create guards inline:
/// ```dart
/// guard((ctx, event) => ctx.isValid && event.hasData)
/// ```
Guard<TContext, TEvent> guard<TContext, TEvent extends XEvent>(
  bool Function(TContext context, TEvent event) condition, {
  String? description,
}) {
  return InlineGuard<TContext, TEvent>(condition, description: description);
}

/// A guard defined with an inline callback function.
class InlineGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final bool Function(TContext context, TEvent event) _condition;

  @override
  final String? description;

  const InlineGuard(this._condition, {this.description});

  @override
  bool evaluate(TContext context, TEvent event) {
    return _condition(context, event);
  }
}

/// A named guard that can be referenced by name.
///
/// Named guards are defined in the machine configuration and can be
/// referenced by name in transitions. This allows for:
/// - Reusing guards across multiple transitions
/// - Overriding guards when testing
/// - Better debugging and visualization
class NamedGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  /// The name of this guard.
  final String name;

  /// The actual guard implementation.
  final Guard<TContext, TEvent> guard;

  const NamedGuard(this.name, this.guard);

  @override
  String? get description => name;

  @override
  bool evaluate(TContext context, TEvent event) {
    return guard.evaluate(context, event);
  }
}

/// A guard that always returns true.
///
/// Useful as a default guard or placeholder.
class AlwaysGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  const AlwaysGuard();

  @override
  String? get description => 'always';

  @override
  bool evaluate(TContext context, TEvent event) => true;
}

/// A guard that always returns false.
///
/// Useful for disabling transitions temporarily.
class NeverGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  const NeverGuard();

  @override
  String? get description => 'never';

  @override
  bool evaluate(TContext context, TEvent event) => false;
}

/// A guard that matches a specific state.
///
/// Example:
/// ```dart
/// ..on<SubmitEvent>('submitting',
///   guard: inState('idle'),
/// )
/// ```
Guard<TContext, TEvent> inState<TContext, TEvent extends XEvent>(
  String stateId,
) {
  return InStateGuard<TContext, TEvent>(stateId);
}

/// A guard that checks if the machine is in a specific state.
///
/// Note: This guard requires access to the current state, which is
/// typically provided through the context or a special accessor.
class InStateGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final String stateId;

  const InStateGuard(this.stateId);

  @override
  String? get description => 'inState($stateId)';

  @override
  bool evaluate(TContext context, TEvent event) {
    // This is a placeholder - actual state checking requires
    // access to the current state value, which would be provided
    // through the context or a special mechanism
    throw UnimplementedError(
      'InStateGuard requires state access mechanism to be implemented',
    );
  }
}

/// Extension to convert guard callbacks to Guard objects.
extension GuardCallbackExtension<TContext, TEvent extends XEvent>
    on bool Function(TContext, TEvent) {
  /// Convert this callback to a [Guard].
  Guard<TContext, TEvent> toGuard({String? description}) {
    return InlineGuard<TContext, TEvent>(this, description: description);
  }
}

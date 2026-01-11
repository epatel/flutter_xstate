import '../events/x_event.dart';
import 'guard.dart';

/// Creates a guard that returns true only if ALL guards return true.
///
/// Example:
/// ```dart
/// ..on<SubmitEvent>('submitting',
///   guard: and([
///     guard((ctx, _) => ctx.isValid),
///     guard((ctx, _) => ctx.hasPermission),
///   ]),
/// )
/// ```
Guard<TContext, TEvent> and<TContext, TEvent extends XEvent>(
  List<Guard<TContext, TEvent>> guards,
) {
  return AndGuard<TContext, TEvent>(guards);
}

/// A guard that returns true only if all child guards return true.
class AndGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final List<Guard<TContext, TEvent>> guards;

  const AndGuard(this.guards);

  @override
  String? get description {
    final descriptions = guards
        .map((g) => g.description ?? 'guard')
        .join(' && ');
    return '($descriptions)';
  }

  @override
  bool evaluate(TContext context, TEvent event) {
    return guards.every((g) => g.evaluate(context, event));
  }
}

/// Creates a guard that returns true if ANY guard returns true.
///
/// Example:
/// ```dart
/// ..on<AccessEvent>('granted',
///   guard: or([
///     guard((ctx, _) => ctx.isAdmin),
///     guard((ctx, _) => ctx.isOwner),
///   ]),
/// )
/// ```
Guard<TContext, TEvent> or<TContext, TEvent extends XEvent>(
  List<Guard<TContext, TEvent>> guards,
) {
  return OrGuard<TContext, TEvent>(guards);
}

/// A guard that returns true if any child guard returns true.
class OrGuard<TContext, TEvent extends XEvent> extends Guard<TContext, TEvent> {
  final List<Guard<TContext, TEvent>> guards;

  const OrGuard(this.guards);

  @override
  String? get description {
    final descriptions = guards
        .map((g) => g.description ?? 'guard')
        .join(' || ');
    return '($descriptions)';
  }

  @override
  bool evaluate(TContext context, TEvent event) {
    return guards.any((g) => g.evaluate(context, event));
  }
}

/// Creates a guard that returns the opposite of another guard.
///
/// Example:
/// ```dart
/// ..on<DeleteEvent>('deleting',
///   guard: not(guard((ctx, _) => ctx.isProtected)),
/// )
/// ```
Guard<TContext, TEvent> not<TContext, TEvent extends XEvent>(
  Guard<TContext, TEvent> guard,
) {
  return NotGuard<TContext, TEvent>(guard);
}

/// A guard that negates another guard.
class NotGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final Guard<TContext, TEvent> _guard;

  const NotGuard(this._guard);

  @override
  String? get description => '!${_guard.description ?? 'guard'}';

  @override
  bool evaluate(TContext context, TEvent event) {
    return !_guard.evaluate(context, event);
  }
}

/// Creates a guard that returns true if exactly one guard returns true.
///
/// Example:
/// ```dart
/// ..on<ToggleEvent>('toggled',
///   guard: xor([
///     guard((ctx, _) => ctx.optionA),
///     guard((ctx, _) => ctx.optionB),
///   ]),
/// )
/// ```
Guard<TContext, TEvent> xor<TContext, TEvent extends XEvent>(
  List<Guard<TContext, TEvent>> guards,
) {
  return XorGuard<TContext, TEvent>(guards);
}

/// A guard that returns true if exactly one child guard returns true.
class XorGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final List<Guard<TContext, TEvent>> guards;

  const XorGuard(this.guards);

  @override
  String? get description {
    final descriptions = guards
        .map((g) => g.description ?? 'guard')
        .join(' ^ ');
    return '($descriptions)';
  }

  @override
  bool evaluate(TContext context, TEvent event) {
    int trueCount = 0;
    for (final g in guards) {
      if (g.evaluate(context, event)) {
        trueCount++;
        if (trueCount > 1) return false;
      }
    }
    return trueCount == 1;
  }
}

/// Creates a guard that checks if a context property equals a value.
///
/// Example:
/// ```dart
/// ..on<StartEvent>('running',
///   guard: equalsValue((ctx) => ctx.status, 'ready'),
/// )
/// ```
Guard<TContext, TEvent> equalsValue<TContext, TEvent extends XEvent, T>(
  T Function(TContext context) selector,
  T value,
) {
  return EqualsGuard<TContext, TEvent, T>(selector, value);
}

/// A guard that checks if a selected value equals an expected value.
class EqualsGuard<TContext, TEvent extends XEvent, T>
    extends Guard<TContext, TEvent> {
  final T Function(TContext context) _selector;
  final T _expected;

  const EqualsGuard(this._selector, this._expected);

  @override
  String? get description => 'equals($_expected)';

  @override
  bool evaluate(TContext context, TEvent event) {
    return _selector(context) == _expected;
  }
}

/// Creates a guard that checks if a context property is greater than a value.
///
/// Example:
/// ```dart
/// ..on<DecrementEvent>('active',
///   guard: isGreaterThan((ctx) => ctx.count, 0),
/// )
/// ```
Guard<TContext, TEvent> isGreaterThan<TContext, TEvent extends XEvent>(
  num Function(TContext context) selector,
  num value,
) {
  return GreaterThanGuard<TContext, TEvent>(selector, value);
}

/// A guard that checks if a selected value is greater than a threshold.
class GreaterThanGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final num Function(TContext context) _selector;
  final num _threshold;

  const GreaterThanGuard(this._selector, this._threshold);

  @override
  String? get description => '> $_threshold';

  @override
  bool evaluate(TContext context, TEvent event) {
    return _selector(context) > _threshold;
  }
}

/// Creates a guard that checks if a context property is less than a value.
///
/// Example:
/// ```dart
/// ..on<IncrementEvent>('active',
///   guard: isLessThan((ctx) => ctx.count, 100),
/// )
/// ```
Guard<TContext, TEvent> isLessThan<TContext, TEvent extends XEvent>(
  num Function(TContext context) selector,
  num value,
) {
  return LessThanGuard<TContext, TEvent>(selector, value);
}

/// A guard that checks if a selected value is less than a threshold.
class LessThanGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final num Function(TContext context) _selector;
  final num _threshold;

  const LessThanGuard(this._selector, this._threshold);

  @override
  String? get description => '< $_threshold';

  @override
  bool evaluate(TContext context, TEvent event) {
    return _selector(context) < _threshold;
  }
}

/// Creates a guard that checks if a context value is in a range.
///
/// Example:
/// ```dart
/// ..on<AdjustEvent>('adjusting',
///   guard: inRange((ctx) => ctx.value, 0, 100),
/// )
/// ```
Guard<TContext, TEvent> inRange<TContext, TEvent extends XEvent>(
  num Function(TContext context) selector,
  num min,
  num max,
) {
  return InRangeGuard<TContext, TEvent>(selector, min, max);
}

/// A guard that checks if a selected value is within a range.
class InRangeGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final num Function(TContext context) _selector;
  final num _min;
  final num _max;

  const InRangeGuard(this._selector, this._min, this._max);

  @override
  String? get description => 'in [$_min, $_max]';

  @override
  bool evaluate(TContext context, TEvent event) {
    final value = _selector(context);
    return value >= _min && value <= _max;
  }
}

/// Creates a guard that checks if a context property is null.
///
/// Example:
/// ```dart
/// ..on<LoadEvent>('loading',
///   guard: isNullValue((ctx) => ctx.data),
/// )
/// ```
Guard<TContext, TEvent> isNullValue<TContext, TEvent extends XEvent>(
  Object? Function(TContext context) selector,
) {
  return IsNullGuard<TContext, TEvent>(selector);
}

/// A guard that checks if a selected value is null.
class IsNullGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final Object? Function(TContext context) _selector;

  const IsNullGuard(this._selector);

  @override
  String? get description => 'isNull';

  @override
  bool evaluate(TContext context, TEvent event) {
    return _selector(context) == null;
  }
}

/// Creates a guard that checks if a context property is not null.
///
/// Example:
/// ```dart
/// ..on<ProcessEvent>('processing',
///   guard: isNotNullValue((ctx) => ctx.data),
/// )
/// ```
Guard<TContext, TEvent> isNotNullValue<TContext, TEvent extends XEvent>(
  Object? Function(TContext context) selector,
) {
  return IsNotNullGuard<TContext, TEvent>(selector);
}

/// A guard that checks if a selected value is not null.
class IsNotNullGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final Object? Function(TContext context) _selector;

  const IsNotNullGuard(this._selector);

  @override
  String? get description => 'isNotNull';

  @override
  bool evaluate(TContext context, TEvent event) {
    return _selector(context) != null;
  }
}

/// Creates a guard that checks if a collection is empty.
///
/// Example:
/// ```dart
/// ..on<AddEvent>('adding',
///   guard: isEmptyCollection((ctx) => ctx.items),
/// )
/// ```
Guard<TContext, TEvent> isEmptyCollection<TContext, TEvent extends XEvent>(
  Iterable<Object?> Function(TContext context) selector,
) {
  return IsEmptyGuard<TContext, TEvent>(selector);
}

/// A guard that checks if a selected collection is empty.
class IsEmptyGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final Iterable<Object?> Function(TContext context) _selector;

  const IsEmptyGuard(this._selector);

  @override
  String? get description => 'isEmpty';

  @override
  bool evaluate(TContext context, TEvent event) {
    return _selector(context).isEmpty;
  }
}

/// Creates a guard that checks if a collection is not empty.
///
/// Example:
/// ```dart
/// ..on<ProcessEvent>('processing',
///   guard: isNotEmptyCollection((ctx) => ctx.items),
/// )
/// ```
Guard<TContext, TEvent> isNotEmptyCollection<TContext, TEvent extends XEvent>(
  Iterable<Object?> Function(TContext context) selector,
) {
  return IsNotEmptyGuard<TContext, TEvent>(selector);
}

/// A guard that checks if a selected collection is not empty.
class IsNotEmptyGuard<TContext, TEvent extends XEvent>
    extends Guard<TContext, TEvent> {
  final Iterable<Object?> Function(TContext context) _selector;

  const IsNotEmptyGuard(this._selector);

  @override
  String? get description => 'isNotEmpty';

  @override
  bool evaluate(TContext context, TEvent event) {
    return _selector(context).isNotEmpty;
  }
}

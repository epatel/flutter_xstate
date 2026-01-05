import 'package:flutter/foundation.dart';

import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';

/// A [Listenable] that notifies listeners when a state machine's state changes.
///
/// This is designed to be used with go_router's `refreshListenable` parameter
/// to trigger route re-evaluation when the state machine's state changes.
///
/// Example:
/// ```dart
/// final authActor = authMachine.createActor()..start();
///
/// final router = GoRouter(
///   refreshListenable: StateMachineRefreshListenable(authActor),
///   redirect: (context, state) {
///     final isLoggedIn = authActor.matches('authenticated');
///     if (!isLoggedIn && !state.matchedLocation.startsWith('/login')) {
///       return '/login';
///     }
///     return null;
///   },
///   routes: [...],
/// );
/// ```
class StateMachineRefreshListenable<TContext, TEvent extends XEvent>
    extends ChangeNotifier {
  /// The actor to listen to.
  final StateMachineActor<TContext, TEvent> _actor;

  /// Optional filter to determine when to notify listeners.
  ///
  /// If provided, listeners are only notified when this returns true.
  final bool Function(
    StateSnapshot<TContext> previous,
    StateSnapshot<TContext> current,
  )? _shouldNotify;

  /// The previous state snapshot.
  StateSnapshot<TContext>? _previousSnapshot;

  /// Creates a refresh listenable that listens to the given actor.
  ///
  /// Optionally provide [shouldNotify] to filter which state changes
  /// trigger a notification.
  StateMachineRefreshListenable(
    this._actor, {
    bool Function(
      StateSnapshot<TContext> previous,
      StateSnapshot<TContext> current,
    )? shouldNotify,
  }) : _shouldNotify = shouldNotify {
    _previousSnapshot = _actor.snapshot;
    _actor.addListener(_onStateChange);
  }

  void _onStateChange() {
    final current = _actor.snapshot;
    final previous = _previousSnapshot;
    final shouldNotify = _shouldNotify;

    if (previous != null && shouldNotify != null) {
      if (!shouldNotify(previous, current)) {
        _previousSnapshot = current;
        return;
      }
    }

    _previousSnapshot = current;
    notifyListeners();
  }

  @override
  void dispose() {
    _actor.removeListener(_onStateChange);
    super.dispose();
  }
}

/// A [Listenable] that combines multiple state machine actors.
///
/// Notifies listeners when any of the actors' states change.
///
/// Example:
/// ```dart
/// final router = GoRouter(
///   refreshListenable: MultiStateMachineRefreshListenable([
///     authActor,
///     permissionsActor,
///   ]),
///   redirect: (context, state) {
///     // Check multiple actors for redirect logic
///     if (!authActor.matches('authenticated')) return '/login';
///     if (!permissionsActor.matches('loaded')) return '/loading';
///     return null;
///   },
///   routes: [...],
/// );
/// ```
class MultiStateMachineRefreshListenable extends ChangeNotifier {
  /// The actors to listen to.
  final List<ChangeNotifier> _actors;

  /// Creates a refresh listenable that listens to multiple actors.
  MultiStateMachineRefreshListenable(this._actors) {
    for (final actor in _actors) {
      actor.addListener(_onStateChange);
    }
  }

  void _onStateChange() {
    notifyListeners();
  }

  @override
  void dispose() {
    for (final actor in _actors) {
      actor.removeListener(_onStateChange);
    }
    super.dispose();
  }
}

/// A [Listenable] that notifies when specific state values are selected.
///
/// Only notifies listeners when the selected value changes, reducing
/// unnecessary route re-evaluations.
///
/// Example:
/// ```dart
/// final router = GoRouter(
///   refreshListenable: StateMachineValueRefreshListenable(
///     authActor,
///     selector: (ctx) => ctx.isAuthenticated,
///   ),
///   redirect: (context, state) {
///     if (!authActor.snapshot.context.isAuthenticated) {
///       return '/login';
///     }
///     return null;
///   },
///   routes: [...],
/// );
/// ```
class StateMachineValueRefreshListenable<TContext, TEvent extends XEvent,
    TSelected> extends ChangeNotifier {
  /// The actor to listen to.
  final StateMachineActor<TContext, TEvent> _actor;

  /// The selector function.
  final TSelected Function(TContext context) _selector;

  /// Optional equality function.
  final bool Function(TSelected previous, TSelected current)? _equals;

  /// The previous selected value.
  TSelected? _previousValue;

  /// Whether this is the first notification.
  bool _isFirst = true;

  /// Creates a value-based refresh listenable.
  ///
  /// The [selector] function extracts the value to watch from the context.
  /// Optionally provide [equals] for custom equality comparison.
  StateMachineValueRefreshListenable(
    this._actor, {
    required TSelected Function(TContext context) selector,
    bool Function(TSelected previous, TSelected current)? equals,
  })  : _selector = selector,
        _equals = equals {
    _previousValue = _selector(_actor.snapshot.context);
    _actor.addListener(_onStateChange);
  }

  void _onStateChange() {
    final current = _selector(_actor.snapshot.context);
    final previous = _previousValue;
    final equals = _equals;

    if (_isFirst) {
      _isFirst = false;
      _previousValue = current;
      notifyListeners();
      return;
    }

    final isEqual = equals != null
        ? equals(previous as TSelected, current)
        : previous == current;

    if (!isEqual) {
      _previousValue = current;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _actor.removeListener(_onStateChange);
    super.dispose();
  }
}

/// A [Listenable] that only notifies when the state value changes.
///
/// This is useful when you only care about state transitions, not context changes.
///
/// Example:
/// ```dart
/// final router = GoRouter(
///   refreshListenable: StateMachineStateRefreshListenable(authActor),
///   redirect: (context, state) {
///     if (authActor.matches('unauthenticated')) return '/login';
///     return null;
///   },
///   routes: [...],
/// );
/// ```
class StateMachineStateRefreshListenable<TContext, TEvent extends XEvent>
    extends ChangeNotifier {
  /// The actor to listen to.
  final StateMachineActor<TContext, TEvent> _actor;

  /// The previous state value.
  String? _previousStateValue;

  /// Creates a state-only refresh listenable.
  StateMachineStateRefreshListenable(this._actor) {
    _previousStateValue = _actor.snapshot.value.toString();
    _actor.addListener(_onStateChange);
  }

  void _onStateChange() {
    final current = _actor.snapshot.value.toString();

    if (current != _previousStateValue) {
      _previousStateValue = current;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _actor.removeListener(_onStateChange);
    super.dispose();
  }
}

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/state_machine.dart';
import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';
import 'state_machine_page.dart';

/// A widget that creates a state machine actor scoped to a page's lifecycle.
///
/// The actor is created when the page is mounted and disposed when
/// the page is removed from the navigation stack. This is useful for
/// page-specific state machines.
///
/// Example:
/// ```dart
/// StateMachinePage(
///   stateId: 'checkout',
///   child: ScopedMachine<CheckoutContext, CheckoutEvent>(
///     machine: checkoutMachine,
///     builder: (context, actor) => CheckoutScreen(),
///   ),
/// )
/// ```
class ScopedMachine<TContext, TEvent extends XEvent> extends StatefulWidget {
  /// The state machine definition.
  final StateMachine<TContext, TEvent> machine;

  /// Optional initial snapshot to restore state.
  final StateSnapshot<TContext>? initialSnapshot;

  /// Builder function that receives the actor.
  final Widget Function(
    BuildContext context,
    StateMachineActor<TContext, TEvent> actor,
  )
  builder;

  /// Callback when the actor is created.
  final void Function(StateMachineActor<TContext, TEvent> actor)? onCreated;

  /// Callback when the actor is disposed.
  final void Function(StateMachineActor<TContext, TEvent> actor)? onDisposed;

  /// Whether to automatically start the actor.
  final bool autoStart;

  const ScopedMachine({
    super.key,
    required this.machine,
    required this.builder,
    this.initialSnapshot,
    this.onCreated,
    this.onDisposed,
    this.autoStart = true,
  });

  @override
  State<ScopedMachine<TContext, TEvent>> createState() =>
      _ScopedMachineState<TContext, TEvent>();
}

class _ScopedMachineState<TContext, TEvent extends XEvent>
    extends State<ScopedMachine<TContext, TEvent>> {
  late StateMachineActor<TContext, TEvent> _actor;

  @override
  void initState() {
    super.initState();
    _actor = widget.machine.createActor(
      initialSnapshot: widget.initialSnapshot,
    );
    widget.onCreated?.call(_actor);
    if (widget.autoStart) {
      _actor.start();
    }
  }

  @override
  void dispose() {
    widget.onDisposed?.call(_actor);
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StateMachineActor<TContext, TEvent>>.value(
      value: _actor,
      child: widget.builder(context, _actor),
    );
  }
}

/// A page that creates a scoped state machine for its child.
///
/// This combines [StateMachinePage] with [ScopedMachine] for convenience.
///
/// Example:
/// ```dart
/// ScopedMachinePage<CheckoutContext, CheckoutEvent>(
///   stateId: 'checkout',
///   machine: checkoutMachine,
///   childBuilder: (context, actor) => CheckoutScreen(),
///   transitionBuilder: StateMachineTransitions.slideFromRight,
/// )
/// ```
class ScopedMachinePage<TContext, TEvent extends XEvent>
    extends StateMachinePage<void> {
  /// Creates a page with a scoped state machine.
  ScopedMachinePage({
    required super.stateId,
    required StateMachine<TContext, TEvent> machine,
    required Widget Function(
      BuildContext context,
      StateMachineActor<TContext, TEvent> actor,
    )
    childBuilder,
    StateSnapshot<TContext>? initialSnapshot,
    void Function(StateMachineActor<TContext, TEvent> actor)? onCreated,
    void Function(StateMachineActor<TContext, TEvent> actor)? onDisposed,
    bool autoStart = true,
    super.key,
    super.name,
    super.transitionBuilder,
    super.transitionDuration,
    super.reverseTransitionDuration,
    super.maintainState,
    super.opaque,
    super.fullscreenDialog,
    super.barrierColor,
    super.barrierLabel,
    super.barrierDismissible,
  }) : super(
         child: ScopedMachine<TContext, TEvent>(
           machine: machine,
           initialSnapshot: initialSnapshot,
           onCreated: onCreated,
           onDisposed: onDisposed,
           autoStart: autoStart,
           builder: childBuilder,
         ),
       );
}

/// A widget that restores state machine state from URL parameters.
///
/// This is useful for restoring state when deep linking or navigating
/// back to a page.
///
/// Example:
/// ```dart
/// RestoredMachine<WizardContext, WizardEvent>(
///   machine: wizardMachine,
///   restoreFrom: (params) {
///     final step = params['step'] ?? 'intro';
///     return StateSnapshot(
///       value: AtomicStateValue(step),
///       context: WizardContext(),
///       event: InitEvent(),
///     );
///   },
///   params: {'step': 'payment'},
///   builder: (context, actor) => WizardScreen(),
/// )
/// ```
class RestoredMachine<TContext, TEvent extends XEvent> extends StatefulWidget {
  /// The state machine definition.
  final StateMachine<TContext, TEvent> machine;

  /// Function to restore state from URL parameters.
  final StateSnapshot<TContext> Function(Map<String, String> params)
  restoreFrom;

  /// The URL parameters to restore from.
  final Map<String, String> params;

  /// Builder function that receives the actor.
  final Widget Function(
    BuildContext context,
    StateMachineActor<TContext, TEvent> actor,
  )
  builder;

  /// Callback when the actor is created.
  final void Function(StateMachineActor<TContext, TEvent> actor)? onCreated;

  /// Whether to automatically start the actor.
  final bool autoStart;

  const RestoredMachine({
    super.key,
    required this.machine,
    required this.restoreFrom,
    required this.params,
    required this.builder,
    this.onCreated,
    this.autoStart = true,
  });

  @override
  State<RestoredMachine<TContext, TEvent>> createState() =>
      _RestoredMachineState<TContext, TEvent>();
}

class _RestoredMachineState<TContext, TEvent extends XEvent>
    extends State<RestoredMachine<TContext, TEvent>> {
  StateMachineActor<TContext, TEvent>? _actor;
  Map<String, String>? _lastParams;

  @override
  void initState() {
    super.initState();
    _createActor();
  }

  @override
  void didUpdateWidget(RestoredMachine<TContext, TEvent> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recreate actor if params changed
    if (!_paramsEqual(widget.params, _lastParams)) {
      _actor?.dispose();
      _createActor();
    }
  }

  bool _paramsEqual(Map<String, String> a, Map<String, String>? b) {
    if (b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  void _createActor() {
    _lastParams = Map.from(widget.params);
    final snapshot = widget.restoreFrom(widget.params);
    _actor = widget.machine.createActor(initialSnapshot: snapshot);
    widget.onCreated?.call(_actor!);

    if (widget.autoStart) {
      _actor!.start();
    }
  }

  @override
  void dispose() {
    _actor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_actor == null) {
      return const SizedBox.shrink();
    }

    return ChangeNotifierProvider<StateMachineActor<TContext, TEvent>>.value(
      value: _actor!,
      child: widget.builder(context, _actor!),
    );
  }
}

/// A widget that synchronizes state machine state with URL parameters.
///
/// When the state machine's state changes, the URL is updated.
/// This provides bidirectional sync between navigation and state.
///
/// Example:
/// ```dart
/// SyncedMachine<WizardContext, WizardEvent>(
///   machine: wizardMachine,
///   toParams: (snapshot) => {'step': snapshot.value.toString()},
///   fromParams: (params) => params['step'] ?? 'intro',
///   onParamsChanged: (params) {
///     // Update URL
///     router.go('/wizard/${params['step']}');
///   },
///   builder: (context, actor) => WizardScreen(),
/// )
/// ```
class SyncedMachine<TContext, TEvent extends XEvent> extends StatefulWidget {
  /// The state machine definition.
  final StateMachine<TContext, TEvent> machine;

  /// Function to convert state to URL parameters.
  final Map<String, String> Function(StateSnapshot<TContext> snapshot) toParams;

  /// Function to get state ID from URL parameters.
  final String Function(Map<String, String> params) fromParams;

  /// Called when parameters should change (state changed).
  final void Function(Map<String, String> params)? onParamsChanged;

  /// Initial URL parameters.
  final Map<String, String> initialParams;

  /// Builder function that receives the actor.
  final Widget Function(
    BuildContext context,
    StateMachineActor<TContext, TEvent> actor,
  )
  builder;

  /// Whether to sync state changes to URL.
  final bool syncToUrl;

  const SyncedMachine({
    super.key,
    required this.machine,
    required this.toParams,
    required this.fromParams,
    required this.builder,
    this.onParamsChanged,
    this.initialParams = const {},
    this.syncToUrl = true,
  });

  @override
  State<SyncedMachine<TContext, TEvent>> createState() =>
      _SyncedMachineState<TContext, TEvent>();
}

class _SyncedMachineState<TContext, TEvent extends XEvent>
    extends State<SyncedMachine<TContext, TEvent>> {
  late StateMachineActor<TContext, TEvent> _actor;
  bool _isSyncing = false;
  String? _lastStateValue;

  @override
  void initState() {
    super.initState();
    _actor = widget.machine.createActor();
    _actor.addListener(_onStateChange);
    _actor.start();
  }

  void _onStateChange() {
    if (!widget.syncToUrl || _isSyncing) return;

    final currentStateValue = _actor.snapshot.value.toString();
    if (currentStateValue != _lastStateValue) {
      _lastStateValue = currentStateValue;
      _isSyncing = true;

      final newParams = widget.toParams(_actor.snapshot);
      widget.onParamsChanged?.call(newParams);

      _isSyncing = false;
    }
  }

  @override
  void dispose() {
    _actor.removeListener(_onStateChange);
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StateMachineActor<TContext, TEvent>>.value(
      value: _actor,
      child: widget.builder(context, _actor),
    );
  }
}

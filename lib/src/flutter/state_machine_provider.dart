import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/state_machine.dart';
import '../core/state_machine_actor.dart';
import '../core/state_snapshot.dart';
import '../events/x_event.dart';

/// Provides a [StateMachineActor] to the widget tree.
///
/// This widget creates an actor from a machine definition and makes it
/// available to descendant widgets via [Provider].
///
/// The actor is automatically started when the widget is mounted and
/// stopped when disposed.
///
/// Example:
/// ```dart
/// StateMachineProvider<AuthContext, AuthEvent>(
///   machine: authMachine,
///   child: MyApp(),
/// )
/// ```
///
/// To access the actor in descendant widgets:
/// ```dart
/// final actor = context.read<StateMachineActor<AuthContext, AuthEvent>>();
/// actor.send(LoginEvent());
/// ```
///
/// Or use the convenience extensions:
/// ```dart
/// final actor = context.actor<AuthContext, AuthEvent>();
/// final state = context.state<AuthContext, AuthEvent>();
/// ```
class StateMachineProvider<TContext, TEvent extends XEvent>
    extends StatefulWidget {
  /// The state machine definition.
  final StateMachine<TContext, TEvent> machine;

  /// The child widget.
  final Widget child;

  /// Optional initial snapshot to restore state.
  final StateSnapshot<TContext>? initialSnapshot;

  /// Whether to automatically start the actor.
  ///
  /// Defaults to true. Set to false if you need to configure the actor
  /// before starting it.
  final bool autoStart;

  /// Callback when the actor is created (before start).
  ///
  /// Use this to configure the actor before it starts.
  final void Function(StateMachineActor<TContext, TEvent> actor)? onCreated;

  const StateMachineProvider({
    super.key,
    required this.machine,
    required this.child,
    this.initialSnapshot,
    this.autoStart = true,
    this.onCreated,
  });

  @override
  State<StateMachineProvider<TContext, TEvent>> createState() =>
      _StateMachineProviderState<TContext, TEvent>();

  /// Read the actor from the nearest ancestor [StateMachineProvider].
  static StateMachineActor<TContext, TEvent> of<TContext, TEvent extends XEvent>(
    BuildContext context, {
    bool listen = false,
  }) {
    if (listen) {
      return context.watch<StateMachineActor<TContext, TEvent>>();
    }
    return context.read<StateMachineActor<TContext, TEvent>>();
  }
}

class _StateMachineProviderState<TContext, TEvent extends XEvent>
    extends State<StateMachineProvider<TContext, TEvent>> {
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
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StateMachineActor<TContext, TEvent>>.value(
      value: _actor,
      child: widget.child,
    );
  }
}

/// Provides an existing [StateMachineActor] to the widget tree.
///
/// Unlike [StateMachineProvider], this widget does not create or manage
/// the actor's lifecycle. Use this when you have an actor that was created
/// elsewhere.
///
/// Example:
/// ```dart
/// final actor = myMachine.createActor();
/// actor.start();
///
/// StateMachineProvider.value(
///   actor: actor,
///   child: MyApp(),
/// )
/// ```
class StateMachineProviderValue<TContext, TEvent extends XEvent>
    extends StatelessWidget {
  /// The actor to provide.
  final StateMachineActor<TContext, TEvent> actor;

  /// The child widget.
  final Widget child;

  const StateMachineProviderValue({
    super.key,
    required this.actor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StateMachineActor<TContext, TEvent>>.value(
      value: actor,
      child: child,
    );
  }
}

/// Multi-provider for multiple state machines.
///
/// Convenience widget for providing multiple state machines at once.
///
/// Example:
/// ```dart
/// MultiStateMachineProvider(
///   providers: [
///     StateMachineProviderItem<AuthContext, AuthEvent>(machine: authMachine),
///     StateMachineProviderItem<ThemeContext, ThemeEvent>(machine: themeMachine),
///   ],
///   child: MyApp(),
/// )
/// ```
class MultiStateMachineProvider extends StatelessWidget {
  /// The list of providers.
  final List<SingleChildWidget> providers;

  /// The child widget.
  final Widget child;

  const MultiStateMachineProvider({
    super.key,
    required this.providers,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: providers,
      child: child,
    );
  }
}

/// Extension methods for accessing state machines from [BuildContext].
extension StateMachineContext on BuildContext {
  /// Get the [StateMachineActor] of type [TContext], [TEvent].
  ///
  /// Does not rebuild when the actor changes. Use [watchActor] for reactive access.
  StateMachineActor<TContext, TEvent> actor<TContext, TEvent extends XEvent>() {
    return read<StateMachineActor<TContext, TEvent>>();
  }

  /// Watch the [StateMachineActor] of type [TContext], [TEvent].
  ///
  /// Rebuilds when the actor's state changes.
  StateMachineActor<TContext, TEvent>
      watchActor<TContext, TEvent extends XEvent>() {
    return watch<StateMachineActor<TContext, TEvent>>();
  }

  /// Get the current [StateSnapshot].
  ///
  /// Does not rebuild when the state changes. Use [watchState] for reactive access.
  StateSnapshot<TContext> state<TContext, TEvent extends XEvent>() {
    return read<StateMachineActor<TContext, TEvent>>().snapshot;
  }

  /// Watch the current [StateSnapshot].
  ///
  /// Rebuilds when the state changes.
  StateSnapshot<TContext> watchState<TContext, TEvent extends XEvent>() {
    return watch<StateMachineActor<TContext, TEvent>>().snapshot;
  }

  /// Send an event to the state machine.
  void send<TContext, TEvent extends XEvent>(TEvent event) {
    read<StateMachineActor<TContext, TEvent>>().send(event);
  }

  /// Check if the state machine matches a state.
  bool matches<TContext, TEvent extends XEvent>(String stateId) {
    return watch<StateMachineActor<TContext, TEvent>>().matches(stateId);
  }
}

/// Typedef for send function passed to builders.
typedef SendEvent<TEvent extends XEvent> = void Function(TEvent event);

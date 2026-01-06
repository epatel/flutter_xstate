/// A state machine library for Flutter inspired by XState.
///
/// flutter_xstate provides type-safe state machines with:
/// - Finite state machines and statecharts
/// - Typed context (data) and events
/// - Entry/exit actions and transition actions
/// - Guard conditions for transitions
/// - Hierarchical (nested) and parallel states
/// - Provider integration for Flutter
/// - go_router integration for navigation
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:flutter_xstate/flutter_xstate.dart';
///
/// // Define your context (data)
/// class CounterContext {
///   final int count;
///   const CounterContext({this.count = 0});
///   CounterContext copyWith({int? count}) =>
///     CounterContext(count: count ?? this.count);
/// }
///
/// // Define your events
/// sealed class CounterEvent extends XEvent {}
///
/// class IncrementEvent extends CounterEvent {
///   @override
///   String get type => 'INCREMENT';
/// }
///
/// // Create the machine
/// final counterMachine = StateMachine.create<CounterContext, CounterEvent>(
///   (m) => m
///     ..context(const CounterContext())
///     ..initial('active')
///     ..state('active', (s) => s
///       ..on<IncrementEvent>('active', actions: [
///         (ctx, _) => ctx.copyWith(count: ctx.count + 1),
///       ])
///     ),
///   id: 'counter',
/// );
///
/// // Create and use an actor
/// final actor = counterMachine.createActor();
/// actor.start();
/// actor.send(IncrementEvent());
/// print(actor.context.count); // 1
/// ```
library;

// Core
export 'src/core/state_machine.dart' show StateMachine;
export 'src/core/state_machine_actor.dart'
    show StateMachineActor, StateMachineActorStream;
export 'src/core/state_snapshot.dart' show StateSnapshot;
export 'src/core/state_value.dart'
    show StateValue, AtomicStateValue, CompoundStateValue, ParallelStateValue;
export 'src/core/transition.dart'
    show Transition, TransitionResult, ActionCallback, GuardCallback;
export 'src/core/state_config.dart' show StateConfig, StateType;

// Events
export 'src/events/x_event.dart'
    show XEvent, SimpleEvent, InitEvent, DoneStateEvent, DoneInvokeEvent, ErrorInvokeEvent;

// Builder
export 'src/builder/machine_builder.dart' show MachineBuilder;
export 'src/builder/state_builder.dart' show StateBuilder;

// Actions
export 'src/actions/action.dart'
    show Action, ActionResult, SendToAction, InlineAction, NamedAction;
export 'src/actions/built_in_actions.dart'
    show
        assign,
        AssignAction,
        raise,
        raiseFrom,
        RaiseAction,
        RaiseFromAction,
        log,
        logMessage,
        LogAction,
        sendTo,
        sendToFrom,
        SendToActionImpl,
        SendToFromAction,
        pure,
        PureAction,
        sequence,
        SequenceAction,
        when,
        ConditionalAction;

// Hierarchy
export 'src/hierarchy/state_node.dart' show StatePath, StateHierarchy;
export 'src/hierarchy/history_state.dart' show HistoryManager, HistoryResolution;
export 'src/hierarchy/transition_resolver.dart'
    show ResolvedTransition, TransitionResolver;

// Guards
export 'src/guards/guard.dart'
    show Guard, guard, InlineGuard, NamedGuard, AlwaysGuard, NeverGuard;
export 'src/guards/guard_combinators.dart'
    show
        and,
        AndGuard,
        or,
        OrGuard,
        not,
        NotGuard,
        xor,
        XorGuard,
        equalsValue,
        EqualsGuard,
        isGreaterThan,
        GreaterThanGuard,
        isLessThan,
        LessThanGuard,
        inRange,
        InRangeGuard,
        isNullValue,
        IsNullGuard,
        isNotNullValue,
        IsNotNullGuard,
        isEmptyCollection,
        IsEmptyGuard,
        isNotEmptyCollection,
        IsNotEmptyGuard;

// Actors
export 'src/actors/actor_ref.dart'
    show
        ActorRef,
        ActorStatus,
        MachineActorRef,
        CallbackActorRef,
        SendToParent,
        ReceiveFromParent;
export 'src/actors/actor_system.dart' show ActorSystem, ActorSystemAccess;
export 'src/actors/spawn_action.dart'
    show
        SpawnConfig,
        SpawnAction,
        SpawnActionResult,
        spawn,
        StopChildAction,
        StopChildActionResult,
        stopChild,
        stopChildDynamic,
        SendToChildAction,
        SendToChildActionResult,
        sendToChild,
        ActorLifecycleHandler;
export 'src/actors/invoke_config.dart'
    show
        InvokeConfig,
        InvokeResult,
        FutureInvokeResult,
        StreamInvokeResult,
        MachineInvokeResult,
        CallbackInvokeResult,
        InvokeFuture,
        InvokeStream,
        InvokeMachine,
        InvokeCallback,
        InvokeFactory,
        invoke;

// Flutter Integration
export 'src/flutter/state_machine_provider.dart'
    show
        StateMachineProvider,
        StateMachineProviderValue,
        MultiStateMachineProvider,
        StateMachineContext,
        SendEvent;
export 'src/flutter/state_machine_builder.dart'
    show
        StateMachineBuilder,
        StateMachineMatchBuilder,
        StateMachineCaseBuilder,
        StateMachineContextBuilder;
export 'src/flutter/state_machine_listener.dart'
    show
        StateMachineListener,
        StateMachineStateListener,
        StateMachineDoneListener,
        StateMachineValueListener,
        MultiStateMachineListener;
export 'src/flutter/state_machine_selector.dart'
    show
        StateMachineSelector,
        StateMachineSelector2,
        StateMachineSelector3,
        StateMachineSelectorWithState,
        StateMachineMatchSelector;
export 'src/flutter/state_machine_consumer.dart'
    show
        StateMachineConsumer,
        StateMachineSelectorConsumer,
        StateMachineMatchConsumer;

// Router Integration (go_router)
export 'src/router/state_machine_refresh_listenable.dart'
    show
        StateMachineRefreshListenable,
        MultiStateMachineRefreshListenable,
        StateMachineValueRefreshListenable,
        StateMachineStateRefreshListenable;
export 'src/router/route_state_redirect.dart'
    show
        StateRedirectFunction,
        redirectWhenMatches,
        redirectWhenNotMatches,
        redirectWhenContext,
        combineRedirects,
        RedirectBuilder,
        StateBasedRedirect,
        RedirectRule,
        SnapshotRedirectExtension;
export 'src/router/route_scoped_machine.dart'
    show
        RouteScopedMachine,
        StateMachineRoute,
        RouteRestoredMachine,
        RouteSyncedMachine,
        RouteStateMachineContext;
export 'src/router/state_machine_router.dart'
    show
        StateRoute,
        StateMachineRouter,
        StateMachineRouterProvider,
        StateMachineRouterMixin,
        createStateMachineRouter,
        GoRouterStateMachineExtension,
        RouterStateMachineContext;

// Delayed Transitions
export 'src/delays/delayed_transition.dart'
    show
        DelayedTransitionConfig,
        PeriodicTransitionConfig,
        DelayedTransitionEvent,
        DelayedTransitionManager,
        DelayedTransitionExtension,
        after,
        every;

// Persistence
export 'src/persistence/state_persistence.dart'
    show
        JsonSerializable,
        SerializedSnapshot,
        StateValueSerializer,
        StatePersistenceAdapter,
        InMemoryPersistenceAdapter,
        StateMachinePersistence,
        AutoSaveConfig,
        SnapshotSerializationExtension;

// DevTools / Inspector
export 'src/devtools/state_machine_inspector.dart'
    show
        TransitionRecord,
        InspectorConfig,
        StateMachineInspector,
        InspectorStats,
        InspectorRegistry,
        InspectorExtension;
export 'src/devtools/inspector_panel.dart'
    show StateMachineInspectorPanel, InspectorOverlay;

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-10

### Added

- **Core State Machine**
  - `StateMachine` - Immutable machine definition with builder API
  - `StateMachineActor` - Runtime instance extending ChangeNotifier
  - `StateSnapshot` - Immutable state snapshots with value and context
  - `StateValue` - Sealed class (Atomic, Compound, Parallel) for exhaustive matching

- **Events**
  - `XEvent` base class for type-safe events
  - Built-in events: `InitEvent`, `DoneStateEvent`, `DoneInvokeEvent`, `ErrorInvokeEvent`

- **Builder API**
  - `MachineBuilder` - Fluent API for machine definition
  - `StateBuilder` - Fluent API for state definition with cascade notation

- **Actions**
  - `assign` - Modify context
  - `raise`, `raiseFrom` - Raise events
  - `log`, `logMessage` - Logging actions
  - `sendTo`, `sendToFrom` - Send events to actors
  - `pure` - Side-effect free actions
  - `sequence` - Run actions in sequence
  - `when` - Conditional actions

- **Guards**
  - `guard` - Create inline guards
  - Combinators: `and`, `or`, `not`, `xor`
  - Value guards: `equalsValue`, `isGreaterThan`, `isLessThan`, `inRange`
  - Null guards: `isNullValue`, `isNotNullValue`
  - Collection guards: `isEmptyCollection`, `isNotEmptyCollection`

- **Hierarchical States**
  - Nested/compound states with dot notation (`player.playing`)
  - Parallel states for concurrent regions
  - History states (shallow and deep)
  - Transition resolution with proper entry/exit ordering

- **Actor System**
  - `ActorRef` - Reference to spawned actors
  - `ActorSystem` - Manage actor hierarchies
  - `spawn` - Spawn child machines
  - `invoke` - Invoke services (Future, Stream, Machine, Callback)

- **Flutter Widgets**
  - `StateMachineProvider` - Provide actor to widget tree
  - `StateMachineBuilder` - Build UI from state
  - `StateMachineSelector` - Selective rebuilds
  - `StateMachineListener` - Listen for state changes
  - `StateMachineConsumer` - Combined builder and listener
  - `MultiStateMachineProvider` - Multiple machines

- **go_router Integration**
  - `StateMachineRefreshListenable` - Trigger router refresh on state change
  - `redirectWhenMatches`, `redirectWhenNotMatches`, `redirectWhenContext` - Redirect helpers
  - `RouteScopedMachine` - Route lifecycle management
  - `StateMachineRouter` - Full router integration

- **Delayed Transitions**
  - `after` - Transition after duration
  - `every` - Periodic actions

- **Persistence**
  - `StateMachinePersistence` - Save and restore snapshots
  - `InMemoryPersistenceAdapter` - Built-in memory adapter
  - Serialization support for state values

- **DevTools**
  - `StateMachineInspector` - Programmatic debugging
  - `StateMachineInspectorPanel` - Visual debugging widget
  - `InspectorOverlay` - Floating debug button
  - Transition history and statistics

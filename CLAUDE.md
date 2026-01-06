# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**flutter_xstate** is a state machine library for Flutter inspired by [XState](https://stately.ai/docs/xstate). It provides type-safe state machines with provider and go_router integration.

## Common Commands

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/core/state_machine_test.dart

# Run tests matching a name pattern
flutter test --name "should transition"

# Static analysis
flutter analyze

# Format code
dart format .

# Fetch dependencies
flutter pub get

# Run a tutorial app
cd tutorial/step1_traffic_light && flutter run -d chrome
```

## Architecture

### Module Structure

```
lib/src/
  core/           # StateMachine, Actor, Snapshot, StateValue, Transition
  events/         # XEvent base class and built-in events
  builder/        # MachineBuilder and StateBuilder fluent API
  actions/        # Built-in actions (assign, raise, log, sendTo, etc.)
  guards/         # Guard interface and combinators (and, or, not, etc.)
  hierarchy/      # StateNode, HistoryManager, TransitionResolver
  actors/         # ActorRef, ActorSystem, spawn, invoke
  flutter/        # Provider, Builder, Selector, Listener, Consumer widgets
  router/         # go_router integration (redirects, route-scoped machines)
  delays/         # DelayedTransition (after, every)
  persistence/    # StateMachinePersistence, adapters
  devtools/       # StateMachineInspector, InspectorPanel
```

### Key Design Patterns

- **Immutable Definitions**: `StateMachine` is immutable; `StateMachineActor` is the mutable runtime
- **Builder Pattern**: Fluent API using Dart cascade notation (`..`)
- **Sealed Classes**: `StateValue` (Atomic/Compound/Parallel) for exhaustive pattern matching
- **ChangeNotifier**: Actor extends ChangeNotifier for provider/go_router integration
- **Type-Safe Generics**: `StateMachine<TContext, TEvent extends XEvent>`

### Core Flow

1. **Define**: `StateMachine.create()` builds immutable machine definition
2. **Create Actor**: `machine.createActor()` creates runtime instance
3. **Start**: `actor.start()` initializes to initial state
4. **Send Events**: `actor.send(event)` triggers transitions
5. **React**: Widgets rebuild via ChangeNotifier

### State Value Types

- `AtomicStateValue` - Simple state: `'idle'`
- `CompoundStateValue` - Nested state: `'player.playing'`
- `ParallelStateValue` - Concurrent regions: `{'bold': 'on', 'italic': 'off'}`

### Transition Resolution

Transitions are resolved in `TransitionResolver`:
1. Find matching transition by event type and guards
2. Calculate exit states (innermost to outermost)
3. Execute exit actions
4. Execute transition actions
5. Calculate entry states (outermost to innermost)
6. Execute entry actions
7. Update history for compound states

## Dependencies

- `provider` ^6.1.0 - State management and DI
- `go_router` ^14.0.0 - Navigation with state-based redirects
- `meta` ^1.10.0 - Annotations (@immutable)
- `collection` ^1.18.0 - Collection utilities
- `mocktail` ^1.0.0 (dev) - Mocking for tests

## Tutorials

Seven progressive tutorials in `tutorial/`:

| Step | Topic | Key Concepts |
|------|-------|--------------|
| 1 | Traffic Light | States, events, transitions |
| 2 | Counter | Context, actions, entry actions |
| 3 | Door Lock | Guards, conditional transitions |
| 4 | Media Player | Hierarchical/nested states |
| 5 | Todo App | Flutter widgets, selectors |
| 6 | Auth Flow | Compound states, async operations |
| 7 | Inspector | Visual debugging panel |

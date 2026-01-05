# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**flutter_xstate** is a state machine library for Flutter inspired by [XState](https://stately.ai/docs/xstate). It provides type-safe state machines with provider and go_router integration.

## Common Commands

```bash
# Run tests
flutter test

# Static analysis
flutter analyze

# Fetch dependencies
flutter pub get

# Format code
dart format .
```

## Architecture

### Library Structure

```
lib/
  flutter_xstate.dart              # Barrel export
  src/
    core/                          # Core state machine
      state_machine.dart           # StateMachine<TContext, TEvent>
      state_machine_actor.dart     # Running actor (ChangeNotifier)
      state_snapshot.dart          # Immutable state snapshot
      state_value.dart             # State identifier (sealed class)
      state_config.dart            # State configuration
      transition.dart              # Transition definition
    events/
      x_event.dart                 # Base event class
    builder/
      machine_builder.dart         # MachineBuilder fluent API
      state_builder.dart           # StateBuilder fluent API
```

### Key Concepts

- **StateMachine**: Pure definition of states, transitions, and actions (immutable)
- **StateMachineActor**: Running instance that extends ChangeNotifier for provider
- **StateSnapshot**: Immutable snapshot containing state value and context
- **StateValue**: Sealed class for atomic, compound, or parallel states
- **XEvent**: Base class for all events

### Design Patterns

- **Builder Pattern**: Fluent API for machine definition using cascade notation
- **ChangeNotifier**: Actor extends ChangeNotifier for provider/go_router integration
- **Sealed Classes**: StateValue uses sealed classes for exhaustive pattern matching
- **Generics**: Type-safe context `TContext` and events `TEvent extends XEvent`

## Implementation Phases

See `/Users/epatel/.claude/plans/serialized-plotting-acorn.md` for the full roadmap.

- **Phase 1** (Complete): Core state machine, events, builder API
- **Phase 2**: Actions (assign, raise, log) and guards
- **Phase 3**: Hierarchical and parallel states
- **Phase 4**: Actor model (spawn, invoke)
- **Phase 5**: Flutter/Provider widgets
- **Phase 6**: go_router integration
- **Phase 7**: Advanced features (delays, persistence)

## Dependencies

- `provider` - State management and DI
- `go_router` - Navigation with state-based redirects
- `meta` - Annotations (@immutable, @internal)
- `collection` - Collection utilities

## Environment

- Dart SDK: ^3.10.4
- Flutter: stable channel

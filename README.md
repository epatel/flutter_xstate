# flutter_xstate

A state machine library for Flutter inspired by [XState](https://stately.ai/docs/xstate). Type-safe state machines with provider and go_router integration.

## Features

- **Finite State Machines** - Define states, events, and transitions
- **Statecharts** - Hierarchical (nested) and parallel states
- **Typed Context** - Store and modify data alongside state
- **Actions** - Entry, exit, and transition actions
- **Guards** - Conditional transitions with composable guard functions
- **Actor Model** - Spawn child machines, invoke services
- **Flutter Widgets** - Provider, Builder, Selector, Listener, Consumer
- **go_router Integration** - State-based redirects and route-scoped machines
- **Delayed Transitions** - `after` and `every` for time-based transitions
- **Persistence** - Save and restore state machine snapshots
- **Inspector Panel** - Visual debugging tools

## Installation

```yaml
dependencies:
  flutter_xstate:
    path: ../flutter_xstate  # or from pub.dev when published
```

## Quick Start

```dart
import 'package:flutter_xstate/flutter_xstate.dart';

// 1. Define your context (data)
class CounterContext {
  final int count;
  const CounterContext({this.count = 0});
  CounterContext copyWith({int? count}) =>
      CounterContext(count: count ?? this.count);
}

// 2. Define your events
sealed class CounterEvent extends XEvent {}

class IncrementEvent extends CounterEvent {
  @override
  String get type => 'INCREMENT';
}

// 3. Create the machine
final counterMachine = StateMachine.create<CounterContext, CounterEvent>(
  (m) => m
    ..context(const CounterContext())
    ..initial('active')
    ..state('active', (s) => s
      ..on<IncrementEvent>('active', actions: [
        (ctx, _) => ctx.copyWith(count: ctx.count + 1),
      ])
    ),
  id: 'counter',
);

// 4. Use in Flutter
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StateMachineProvider<CounterContext, CounterEvent>(
      machine: counterMachine,
      autoStart: true,
      child: StateMachineBuilder<CounterContext, CounterEvent>(
        builder: (context, state, send) {
          return Text('Count: ${state.context.count}');
        },
      ),
    );
  }
}
```

## Core Concepts

### States and Transitions

```dart
StateMachine.create<Context, Event>(
  (m) => m
    ..initial('idle')
    ..state('idle', (s) => s
      ..on<StartEvent>('running')
    )
    ..state('running', (s) => s
      ..on<StopEvent>('idle')
    ),
);
```

### Context and Actions

```dart
..state('active', (s) => s
  ..on<IncrementEvent>('active', actions: [
    (ctx, event) => ctx.copyWith(count: ctx.count + 1),
  ])
  ..entry([
    (ctx, _) => ctx.copyWith(startedAt: DateTime.now()),
  ])
  ..exit([
    (ctx, _) => ctx.copyWith(endedAt: DateTime.now()),
  ])
)
```

### Guards (Conditional Transitions)

```dart
bool hasItems(CartContext ctx, CartEvent event) => ctx.items.isNotEmpty;

..on<CheckoutEvent>('checkout', guard: hasItems)
..on<CheckoutEvent>('error', guard: not(hasItems))
```

### Hierarchical States

```dart
..state('player', (s) => s
  ..initial('paused')
  ..on<StopEvent>('stopped')  // Available in all children

  ..state('playing', (child) => child
    ..on<PauseEvent>('player.paused')
  )
  ..state('paused', (child) => child
    ..on<PlayEvent>('player.playing')
  )
)
```

### Checking State

```dart
state.value.matches('player')          // true if in player or any child
state.value.matches('player.playing')  // true only if in playing
```

## Flutter Widgets

### StateMachineProvider

Provides the actor to the widget tree:

```dart
StateMachineProvider<Context, Event>(
  machine: myMachine,
  autoStart: true,
  child: MyApp(),
)
```

### StateMachineBuilder

Rebuilds on state changes:

```dart
StateMachineBuilder<Context, Event>(
  builder: (context, state, send) {
    return ElevatedButton(
      onPressed: () => send(MyEvent()),
      child: Text('State: ${state.value}'),
    );
  },
)
```

### StateMachineSelector

Only rebuilds when selected value changes:

```dart
StateMachineSelector<Context, Event, int>(
  selector: (ctx) => ctx.count,
  builder: (context, count, send) {
    return Text('Count: $count');
  },
)
```

### StateMachineListener

Listen for state changes without rebuilding:

```dart
StateMachineListener<Context, Event>(
  listener: (context, state) {
    if (state.value.matches('error')) {
      ScaffoldMessenger.of(context).showSnackBar(...);
    }
  },
  child: MyWidget(),
)
```

### StateMachineConsumer

Combines Builder and Listener:

```dart
StateMachineConsumer<Context, Event>(
  listener: (context, state) { /* side effects */ },
  builder: (context, state, send) { /* UI */ },
)
```

## go_router Integration

### State-Based Redirects

```dart
final router = GoRouter(
  refreshListenable: StateMachineRefreshListenable(authActor),
  redirect: (context, state) {
    if (authActor.snapshot.value.matches('loggedOut')) {
      return '/login';
    }
    return null;
  },
  routes: [...],
);
```

### Redirect Helpers

```dart
redirect: combineRedirects([
  redirectWhenMatches(authActor, 'loggedOut', '/login'),
  redirectWhenNotMatches(authActor, 'loggedIn', '/login'),
  redirectWhenContext(authActor, (ctx) => !ctx.isVerified, '/verify'),
]),
```

## Advanced Features

### Built-in Actions

```dart
actions: [
  assign((ctx, e) => ctx.copyWith(...)),  // Modify context
  raise(SomeEvent()),                      // Raise another event
  log('Transition occurred'),              // Log message
  sendTo('childId', SomeEvent()),          // Send to child actor
]
```

### Guard Combinators

```dart
guard: and(isLoggedIn, hasPermission)
guard: or(isAdmin, isOwner)
guard: not(isBlocked)
```

### Delayed Transitions

```dart
..state('idle', (s) => s
  ..after(Duration(seconds: 5), 'timeout')
  ..every(Duration(seconds: 1), actions: [tickAction])
)
```

### Invoke Services

```dart
..state('loading', (s) => s
  ..invoke(
    InvokeFuture((ctx, _) => fetchData()),
    onDone: 'success',
    onError: 'error',
  )
)
```

### Inspector Panel

```dart
StateMachineInspectorPanel<Context, Event>(
  actor: actor,
  machine: machine,
  eventBuilders: {
    'INCREMENT': () => IncrementEvent(),
    'DECREMENT': () => DecrementEvent(),
  },
)
```

## Tutorials

Learn step-by-step with the included tutorials:

| Step | Name | Concepts |
|------|------|----------|
| 1 | [Traffic Light](tutorial/step1_traffic_light/) | States, events, transitions |
| 2 | [Counter](tutorial/step2_counter/) | Context, actions, entry actions |
| 3 | [Door Lock](tutorial/step3_door_lock/) | Guards, conditional transitions |
| 4 | [Media Player](tutorial/step4_hierarchical/) | Hierarchical/nested states |
| 5 | [Todo App](tutorial/step5_todo/) | Flutter widgets, selectors |
| 6 | [Auth Flow](tutorial/step6_auth/) | Compound states, async operations |
| 7 | [Inspector](tutorial/step7_inspector/) | Visual debugging panel |
| 8 | [Multi-Machine](tutorial/step8_multi_machine/) | Multiple machines communicating |
| 9 | [Structured](tutorial/step9_structured/) | Project organization patterns |

Run any tutorial:

```bash
cd tutorial/step1_traffic_light
flutter run -d chrome
```

## API Reference

### Core

- `StateMachine` - Immutable machine definition
- `StateMachineActor` - Running instance (extends ChangeNotifier)
- `StateSnapshot` - Immutable state snapshot with value and context
- `StateValue` - Sealed class (Atomic, Compound, Parallel)
- `XEvent` - Base class for events

### Builder API

- `MachineBuilder` - Fluent API for machine definition
- `StateBuilder` - Fluent API for state definition

### Guards

- `guard()` - Create inline guard
- `and()`, `or()`, `not()`, `xor()` - Combinators
- `equalsValue()`, `isGreaterThan()`, `isLessThan()`, `inRange()`
- `isNullValue()`, `isNotNullValue()`
- `isEmptyCollection()`, `isNotEmptyCollection()`

### Actions

- `assign()` - Modify context
- `raise()`, `raiseFrom()` - Raise events
- `log()`, `logMessage()` - Logging
- `sendTo()`, `sendToFrom()` - Send to actors
- `pure()` - Side-effect free action
- `sequence()` - Run actions in sequence
- `when()` - Conditional action

### Flutter Widgets

- `StateMachineProvider` - Provide actor to tree
- `StateMachineBuilder` - Build UI from state
- `StateMachineSelector` - Selective rebuilds
- `StateMachineListener` - Listen for changes
- `StateMachineConsumer` - Builder + Listener

### Router

- `StateMachineRefreshListenable` - Trigger router refresh
- `redirectWhenMatches()`, `redirectWhenNotMatches()`, `redirectWhenContext()`
- `RouteScopedMachine` - Route lifecycle management

### DevTools

- `StateMachineInspector` - Programmatic debugging
- `StateMachineInspectorPanel` - Visual debugging widget
- `InspectorOverlay` - Floating debug button

## License

MIT

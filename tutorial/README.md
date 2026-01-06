# flutter_xstate Tutorial

Welcome to the flutter_xstate tutorial! This guide walks you through building state machines for Flutter applications.

## Running the Tutorials

Since flutter_xstate depends on Flutter, use `flutter test` to run the examples:

```bash
# Run all tutorials
flutter test test/tutorial/

# Run specific tutorial
flutter test test/tutorial/tutorial_01_test.dart
flutter test test/tutorial/tutorial_02_test.dart
flutter test test/tutorial/tutorial_03_test.dart
```

## Tutorial Steps

### Console Examples (run with flutter test)

| Step | Test File | Topic |
|------|-----------|-------|
| 1 | `test/tutorial/tutorial_01_test.dart` | Basic state machines, events, transitions |
| 2 | `test/tutorial/tutorial_02_test.dart` | Context, actions, entry/exit hooks |
| 3 | `test/tutorial/tutorial_03_test.dart` | Guards and conditional transitions |

### Reference Files (read & copy)

| Step | File | Topic |
|------|------|-------|
| 1 | `tutorial/01_first_state_machine.dart` | Events, states, transitions, actors |
| 2 | `tutorial/02_context_and_actions.dart` | Context data, actions, entry/exit |
| 3 | `tutorial/03_guards.dart` | Guards, combinators (and/or/not) |
| 4 | `tutorial/04_hierarchical_states.dart` | Nested states, parent transitions |
| 5 | `tutorial/05_flutter_widgets.dart` | Provider, Consumer, Builder, Selector |
| 6 | `tutorial/06_auth_example.dart` | Complete auth flow with UI |

## Quick Start

```dart
import 'package:flutter_xstate/flutter_xstate.dart';

// 1. Define events
sealed class MyEvent extends XEvent {}
class StartEvent extends MyEvent {
  @override String get type => 'START';
}
class StopEvent extends MyEvent {
  @override String get type => 'STOP';
}

// 2. Define context (your data)
class MyContext {
  final int count;
  const MyContext({this.count = 0});
  MyContext copyWith({int? count}) => MyContext(count: count ?? this.count);
}

// 3. Create machine
final machine = StateMachine.create<MyContext, MyEvent>((m) => m
  ..context(const MyContext())
  ..initial('idle')
  ..state('idle', (s) => s
    ..on<StartEvent>('running')
  )
  ..state('running', (s) => s
    ..on<StopEvent>('idle')
    ..onEntry((ctx, _) {
      print('Started!');
      return ctx.copyWith(count: ctx.count + 1);
    })
  )
);

// 4. Use it
final actor = machine.createActor()..start();
print(actor.matches('idle'));  // true
actor.send(StartEvent());
print(actor.matches('running'));  // true
print(actor.snapshot.context.count);  // 1
```

## Flutter Integration

```dart
// Provide to widget tree
StateMachineProvider<MyContext, MyEvent>(
  machine: machine,
  autoStart: true,
  child: MyApp(),
)

// Consume in widgets
StateMachineConsumer<MyContext, MyEvent>(
  builder: (context, actor) {
    return Text('Count: ${actor.snapshot.context.count}');
  },
)

// Optimized rebuilds
StateMachineSelector<MyContext, MyEvent, int>(
  selector: (state) => state.context.count,
  builder: (context, count, actor) => Text('Count: $count'),
)
```

## Learning Path

1. **Start with Step 1** - Understand events, states, and transitions
2. **Add data with Step 2** - Learn about context and actions
3. **Control flow with Step 3** - Master guards for conditional logic
4. **Organize with Step 4** - Build hierarchical state machines
5. **Integrate with Step 5** - Connect to your Flutter UI
6. **Apply with Step 6** - See a complete real-world example

Happy state machining!

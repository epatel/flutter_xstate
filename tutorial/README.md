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

| Step | Directory | Topic |
|------|-----------|-------|
| 1 | [step1_traffic_light](step1_traffic_light/) | Basic state machines, events, transitions |
| 2 | [step2_counter](step2_counter/) | Context, actions, entry/exit hooks |
| 3 | [step3_door_lock](step3_door_lock/) | Guards and conditional transitions |
| 4 | [step4_hierarchical](step4_hierarchical/) | Nested/hierarchical states |
| 5 | [step5_todo](step5_todo/) | Flutter widgets, selectors |
| 6 | [step6_auth](step6_auth/) | Complete auth flow with async |
| 7 | [step7_inspector](step7_inspector/) | Visual debugging panel |
| 8 | [step8_multi_machine](step8_multi_machine/) | Multiple machines communicating |

Run any tutorial:

```bash
cd tutorial/step1_traffic_light
flutter run -d chrome
```

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
6. **Apply with Step 6** - See a complete auth flow example
7. **Debug with Step 7** - Use the visual inspector panel
8. **Scale with Step 8** - Coordinate multiple state machines

Happy state machining!

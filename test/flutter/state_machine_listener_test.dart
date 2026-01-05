import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class CounterContext {
  final int count;
  const CounterContext({this.count = 0});
  CounterContext copyWith({int? count}) =>
      CounterContext(count: count ?? this.count);
}

// Test events
sealed class CounterEvent extends XEvent {}

class IncrementEvent extends CounterEvent {
  @override
  String get type => 'INCREMENT';
}

class ResetEvent extends CounterEvent {
  @override
  String get type => 'RESET';
}

class CompleteEvent extends CounterEvent {
  @override
  String get type => 'COMPLETE';
}

void main() {
  late StateMachine<CounterContext, CounterEvent> counterMachine;

  setUp(() {
    counterMachine = StateMachine.create<CounterContext, CounterEvent>(
      (m) => m
        ..context(const CounterContext())
        ..initial('active')
        ..state('active', (s) => s
          ..on<IncrementEvent>('active', actions: [
            (ctx, _) => ctx.copyWith(count: ctx.count + 1),
          ])
          ..on<ResetEvent>('idle')
          ..on<CompleteEvent>('done')
        )
        ..state('idle', (s) => s
          ..on<IncrementEvent>('active')
        )
        ..state('done', (s) => s..final_()),
      id: 'counter',
    );
  });

  group('StateMachineListener', () {
    testWidgets('calls listener on state change', (tester) async {
      final stateChanges = <StateSnapshot<CounterContext>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineListener<CounterContext, CounterEvent>(
              listener: (context, state) {
                stateChanges.add(state);
              },
              child: StateMachineBuilder<CounterContext, CounterEvent>(
                builder: (context, state, send) {
                  return ElevatedButton(
                    onPressed: () => send(IncrementEvent()),
                    child: const Text('Increment'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(stateChanges, isEmpty);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(stateChanges.length, equals(1));
      expect(stateChanges.first.context.count, equals(1));
    });

    testWidgets('respects listenWhen condition', (tester) async {
      final stateChanges = <StateSnapshot<CounterContext>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineListener<CounterContext, CounterEvent>(
              listenWhen: (previous, current) =>
                  current.context.count >= 3,
              listener: (context, state) {
                stateChanges.add(state);
              },
              child: StateMachineBuilder<CounterContext, CounterEvent>(
                builder: (context, state, send) {
                  return ElevatedButton(
                    onPressed: () => send(IncrementEvent()),
                    child: const Text('Increment'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Increment 1-2, listener should not be called
      await tester.tap(find.text('Increment'));
      await tester.pump();
      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(stateChanges, isEmpty);

      // Increment to 3, listener should be called
      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(stateChanges.length, equals(1));
      expect(stateChanges.first.context.count, equals(3));
    });

    testWidgets('does not rebuild child', (tester) async {
      int childBuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineListener<CounterContext, CounterEvent>(
              listener: (context, state) {},
              child: Builder(
                builder: (context) {
                  childBuildCount++;
                  final actor = context.actor<CounterContext, CounterEvent>();
                  return ElevatedButton(
                    onPressed: () => actor.send(IncrementEvent()),
                    child: const Text('Increment'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      final initialBuildCount = childBuildCount;

      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Child should not rebuild from listener
      expect(childBuildCount, equals(initialBuildCount));
    });
  });

  group('StateMachineStateListener', () {
    testWidgets('calls onEnter when entering state', (tester) async {
      int enterCount = 0;
      int exitCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineStateListener<CounterContext, CounterEvent>(
              stateId: 'idle',
              onEnter: (context, state) => enterCount++,
              onExit: (context, state) => exitCount++,
              child: StateMachineBuilder<CounterContext, CounterEvent>(
                builder: (context, state, send) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => send(ResetEvent()),
                        child: const Text('Reset'),
                      ),
                      ElevatedButton(
                        onPressed: () => send(IncrementEvent()),
                        child: const Text('Increment'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(enterCount, equals(0));
      expect(exitCount, equals(0));

      // Enter idle state
      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(enterCount, equals(1));
      expect(exitCount, equals(0));

      // Exit idle state
      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(enterCount, equals(1));
      expect(exitCount, equals(1));
    });
  });

  group('StateMachineDoneListener', () {
    testWidgets('calls onDone when machine completes', (tester) async {
      int doneCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineDoneListener<CounterContext, CounterEvent>(
              onDone: (context, state) => doneCount++,
              child: StateMachineBuilder<CounterContext, CounterEvent>(
                builder: (context, state, send) {
                  return ElevatedButton(
                    onPressed: () => send(CompleteEvent()),
                    child: const Text('Complete'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(doneCount, equals(0));

      await tester.tap(find.text('Complete'));
      await tester.pump();

      expect(doneCount, equals(1));
    });
  });

  group('StateMachineValueListener', () {
    testWidgets('calls listener when value changes', (tester) async {
      final values = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineValueListener<CounterContext, CounterEvent, int>(
              selector: (ctx) => ctx.count,
              listener: (context, state, value) => values.add(value),
              child: StateMachineBuilder<CounterContext, CounterEvent>(
                builder: (context, state, send) {
                  return ElevatedButton(
                    onPressed: () => send(IncrementEvent()),
                    child: const Text('Increment'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(values, equals([1]));

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(values, equals([1, 2]));
    });
  });
}

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
        )
        ..state('idle', (s) => s
          ..on<IncrementEvent>('active')
        ),
      id: 'counter',
    );
  });

  group('StateMachineBuilder', () {
    testWidgets('builds with current state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineBuilder<CounterContext, CounterEvent>(
              builder: (context, state, send) {
                return Text('Count: ${state.context.count}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('rebuilds on state change', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineBuilder<CounterContext, CounterEvent>(
              builder: (context, state, send) {
                return Column(
                  children: [
                    Text('Count: ${state.context.count}'),
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
      );

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('respects buildWhen condition', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineBuilder<CounterContext, CounterEvent>(
              buildWhen: (previous, current) =>
                  current.context.count.isEven != previous.context.count.isEven,
              builder: (context, state, send) {
                buildCount++;
                return Column(
                  children: [
                    Text('Count: ${state.context.count}'),
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
      );

      final initialBuildCount = buildCount;

      // Increment to 1 (odd) - should rebuild (was even)
      await tester.tap(find.text('Increment'));
      await tester.pump();
      expect(buildCount, equals(initialBuildCount + 1));

      // Increment to 2 (even) - should rebuild
      await tester.tap(find.text('Increment'));
      await tester.pump();
      expect(buildCount, equals(initialBuildCount + 2));

      // Increment to 3 (odd) - should rebuild
      await tester.tap(find.text('Increment'));
      await tester.pump();
      expect(buildCount, equals(initialBuildCount + 3));
    });
  });

  group('StateMachineMatchBuilder', () {
    testWidgets('shows match widget when state matches', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineMatchBuilder<CounterContext, CounterEvent>(
              stateId: 'active',
              matchBuilder: (context, state, send) =>
                  const Text('Active State'),
              orElse: (context, state, send) =>
                  const Text('Other State'),
            ),
          ),
        ),
      );

      expect(find.text('Active State'), findsOneWidget);
      expect(find.text('Other State'), findsNothing);
    });

    testWidgets('shows orElse widget when state does not match', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: Column(
              children: [
                StateMachineBuilder<CounterContext, CounterEvent>(
                  builder: (context, state, send) {
                    return ElevatedButton(
                      onPressed: () => send(ResetEvent()),
                      child: const Text('Reset'),
                    );
                  },
                ),
                StateMachineMatchBuilder<CounterContext, CounterEvent>(
                  stateId: 'active',
                  matchBuilder: (context, state, send) =>
                      const Text('Active State'),
                  orElse: (context, state, send) =>
                      const Text('Idle State'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Active State'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(find.text('Idle State'), findsOneWidget);
    });
  });

  group('StateMachineCaseBuilder', () {
    testWidgets('renders correct case', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: StateMachineCaseBuilder<CounterContext, CounterEvent>(
              cases: {
                'active': (context, state, send) => const Text('Is Active'),
                'idle': (context, state, send) => const Text('Is Idle'),
              },
              orElse: (context, state, send) => const Text('Unknown'),
            ),
          ),
        ),
      );

      expect(find.text('Is Active'), findsOneWidget);
    });
  });

  group('StateMachineContextBuilder', () {
    testWidgets('builds based on context condition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: Column(
              children: [
                StateMachineBuilder<CounterContext, CounterEvent>(
                  builder: (context, state, send) {
                    return ElevatedButton(
                      onPressed: () => send(IncrementEvent()),
                      child: const Text('Increment'),
                    );
                  },
                ),
                StateMachineContextBuilder<CounterContext, CounterEvent>(
                  condition: (ctx) => ctx.count >= 3,
                  builder: (context, state, send) =>
                      const Text('High Count'),
                  orElse: (context, state, send) =>
                      const Text('Low Count'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Low Count'), findsOneWidget);

      // Increment 3 times
      await tester.tap(find.text('Increment'));
      await tester.pump();
      await tester.tap(find.text('Increment'));
      await tester.pump();
      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('High Count'), findsOneWidget);
    });
  });
}

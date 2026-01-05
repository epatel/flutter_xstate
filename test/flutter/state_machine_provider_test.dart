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

class DecrementEvent extends CounterEvent {
  @override
  String get type => 'DECREMENT';
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
          ..on<DecrementEvent>('active', actions: [
            (ctx, _) => ctx.copyWith(count: ctx.count - 1),
          ])
        ),
      id: 'counter',
    );
  });

  group('StateMachineProvider', () {
    testWidgets('provides actor to descendants', (tester) async {
      StateMachineActor<CounterContext, CounterEvent>? capturedActor;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: Builder(
              builder: (context) {
                capturedActor =
                    context.actor<CounterContext, CounterEvent>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedActor, isNotNull);
      expect(capturedActor!.snapshot.context.count, equals(0));
    });

    testWidgets('auto-starts actor by default', (tester) async {
      StateMachineActor<CounterContext, CounterEvent>? capturedActor;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: Builder(
              builder: (context) {
                capturedActor =
                    context.actor<CounterContext, CounterEvent>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedActor!.started, isTrue);
    });

    testWidgets('does not auto-start when autoStart is false', (tester) async {
      StateMachineActor<CounterContext, CounterEvent>? capturedActor;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            autoStart: false,
            child: Builder(
              builder: (context) {
                capturedActor =
                    context.actor<CounterContext, CounterEvent>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedActor!.started, isFalse);
    });

    testWidgets('calls onCreated before start', (tester) async {
      StateMachineActor<CounterContext, CounterEvent>? createdActor;
      bool wasStartedWhenCreated = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            onCreated: (actor) {
              createdActor = actor;
              wasStartedWhenCreated = actor.started;
            },
            child: const SizedBox(),
          ),
        ),
      );

      expect(createdActor, isNotNull);
      expect(wasStartedWhenCreated, isFalse);
    });

    testWidgets('disposes actor on widget dispose', (tester) async {
      StateMachineActor<CounterContext, CounterEvent>? capturedActor;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: Builder(
              builder: (context) {
                capturedActor =
                    context.actor<CounterContext, CounterEvent>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedActor!.stopped, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(capturedActor!.stopped, isTrue);
    });

    testWidgets('restores state from initialSnapshot', (tester) async {
      final initialSnapshot = StateSnapshot<CounterContext>(
        value: const AtomicStateValue('active'),
        context: const CounterContext(count: 42),
        event: const InitEvent(),
      );

      StateMachineActor<CounterContext, CounterEvent>? capturedActor;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            initialSnapshot: initialSnapshot,
            child: Builder(
              builder: (context) {
                capturedActor =
                    context.actor<CounterContext, CounterEvent>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedActor!.snapshot.context.count, equals(42));
    });
  });

  group('StateMachineProviderValue', () {
    testWidgets('provides existing actor', (tester) async {
      final actor = counterMachine.createActor();
      actor.start();
      actor.send(IncrementEvent());

      StateMachineActor<CounterContext, CounterEvent>? capturedActor;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProviderValue<CounterContext, CounterEvent>(
            actor: actor,
            child: Builder(
              builder: (context) {
                capturedActor =
                    context.actor<CounterContext, CounterEvent>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedActor, equals(actor));
      expect(capturedActor!.snapshot.context.count, equals(1));

      actor.dispose();
    });
  });

  group('StateMachineContext extension', () {
    testWidgets('send dispatches event', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    context.send<CounterContext, CounterEvent>(IncrementEvent());
                  },
                  child: const Text('Increment'),
                );
              },
            ),
          ),
        ),
      );

      final actor = tester
          .element(find.byType(ElevatedButton))
          .actor<CounterContext, CounterEvent>();

      expect(actor.snapshot.context.count, equals(0));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(actor.snapshot.context.count, equals(1));
    });

    testWidgets('matches checks state', (tester) async {
      bool? isActive;

      await tester.pumpWidget(
        MaterialApp(
          home: StateMachineProvider<CounterContext, CounterEvent>(
            machine: counterMachine,
            child: Builder(
              builder: (context) {
                isActive = context.matches<CounterContext, CounterEvent>('active');
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(isActive, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class CounterContext {
  final int count;
  const CounterContext({this.count = 0});

  CounterContext copyWith({int? count}) =>
      CounterContext(count: count ?? this.count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CounterContext && count == other.count;

  @override
  int get hashCode => count.hashCode;
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
  late StateMachine<CounterContext, CounterEvent> machine;

  setUp(() {
    machine = StateMachine.create<CounterContext, CounterEvent>(
      (m) => m
        ..context(const CounterContext())
        ..initial('active')
        ..state(
          'active',
          (s) => s
            ..on<IncrementEvent>(
              'active',
              actions: [(ctx, _) => ctx.copyWith(count: ctx.count + 1)],
            )
            ..on<DecrementEvent>(
              'active',
              guard: (ctx, _) => ctx.count > 0,
              actions: [(ctx, _) => ctx.copyWith(count: ctx.count - 1)],
            ),
        ),
      id: 'counter',
    );
  });

  group('StateMachineActor lifecycle', () {
    test('actor is not started by default', () {
      final actor = machine.createActor();
      expect(actor.started, isFalse);
      expect(actor.stopped, isFalse);
    });

    test('start sets started flag', () {
      final actor = machine.createActor();
      actor.start();
      expect(actor.started, isTrue);
    });

    test('start can only be called once', () {
      final actor = machine.createActor();
      actor.start();
      // ignore: avoid_print
      print('(Expected warning below)');
      actor.start(); // Should not throw, just no-op
      expect(actor.started, isTrue);
    });

    test('cannot start a stopped actor', () {
      final actor = machine.createActor();
      actor.start();
      actor.stop();

      expect(() => actor.start(), throwsA(isA<StateError>()));
    });

    test('stop sets stopped flag', () {
      final actor = machine.createActor();
      actor.start();
      actor.stop();
      expect(actor.stopped, isTrue);
    });

    test('dispose stops and closes stream', () {
      final actor = machine.createActor();
      actor.start();
      actor.dispose();
      expect(actor.stopped, isTrue);
    });
  });

  group('StateMachineActor.send', () {
    test('cannot send before start', () {
      final actor = machine.createActor();
      // ignore: avoid_print
      print('(Expected warning below)');
      actor.send(IncrementEvent());
      // Should be ignored, count stays at 0
      expect(actor.context.count, equals(0));
    });

    test('cannot send after stop', () {
      final actor = machine.createActor();
      actor.start();
      actor.stop();
      // ignore: avoid_print
      print('(Expected warning below)');
      actor.send(IncrementEvent());
      // Should be ignored
      expect(actor.context.count, equals(0));
    });

    test('sends event and updates state', () {
      final actor = machine.createActor();
      actor.start();
      actor.send(IncrementEvent());
      expect(actor.context.count, equals(1));
    });

    test('multiple sends accumulate', () {
      final actor = machine.createActor();
      actor.start();
      actor.send(IncrementEvent());
      actor.send(IncrementEvent());
      actor.send(IncrementEvent());
      expect(actor.context.count, equals(3));
    });
  });

  group('StateMachineActor state accessors', () {
    test('snapshot returns current state', () {
      final actor = machine.createActor();
      expect(actor.snapshot, isA<StateSnapshot<CounterContext>>());
    });

    test('stateValue returns current value', () {
      final actor = machine.createActor();
      expect(actor.stateValue, isA<StateValue>());
    });

    test('context returns current context', () {
      final actor = machine.createActor();
      expect(actor.context, isA<CounterContext>());
    });

    test('matches delegates to snapshot', () {
      final actor = machine.createActor();
      expect(actor.matches('active'), isTrue);
      expect(actor.matches('idle'), isFalse);
    });

    test('done returns false for non-final state', () {
      final actor = machine.createActor();
      expect(actor.done, isFalse);
    });
  });

  group('StateMachineActor with final state', () {
    test('done is true when in final state', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('active')
          ..state('active', (s) => s..on<IncrementEvent>('done'))
          ..state('done', (s) => s..final_()),
        id: 'counter',
      );

      final actor = machine.createActor();
      actor.start();
      actor.send(IncrementEvent());

      expect(actor.done, isTrue);
    });

    test('cannot send to final state', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('active')
          ..state(
            'active',
            (s) => s
              ..on<IncrementEvent>(
                'done',
                actions: [(ctx, _) => ctx.copyWith(count: 1)],
              ),
          )
          ..state('done', (s) => s..final_()),
        id: 'counter',
      );

      final actor = machine.createActor();
      actor.start();
      actor.send(IncrementEvent()); // -> done, count = 1

      // Further sends should be ignored
      // ignore: avoid_print
      print('(Expected warning below)');
      actor.send(IncrementEvent());
      expect(actor.context.count, equals(1));
    });
  });

  group('StateMachineActor ChangeNotifier', () {
    test('notifies listeners on state change', () {
      final actor = machine.createActor();
      var notifyCount = 0;
      actor.addListener(() => notifyCount++);

      actor.start();
      expect(notifyCount, equals(1)); // Initial notification

      actor.send(IncrementEvent());
      expect(notifyCount, equals(2));
    });

    test('does not notify if no state change', () {
      final actor = machine.createActor();
      var notifyCount = 0;
      actor.addListener(() => notifyCount++);

      actor.start();
      expect(notifyCount, equals(1));

      // Decrement with count=0 should fail guard, no change
      actor.send(DecrementEvent());
      expect(notifyCount, equals(1)); // Still 1
    });
  });

  group('StateMachineActor ValueListenable', () {
    test('value returns current snapshot', () {
      final actor = machine.createActor();
      expect(actor.value, equals(actor.snapshot));
    });
  });

  group('StateMachineActor stream', () {
    test('stream emits on state change', () async {
      final actor = machine.createActor();
      final states = <StateSnapshot<CounterContext>>[];

      actor.stream.listen(states.add);
      actor.start();
      actor.send(IncrementEvent());
      actor.send(IncrementEvent());

      await Future<void>.delayed(Duration.zero);

      expect(states.length, equals(3)); // initial + 2 increments
      expect(states[0].context.count, equals(0));
      expect(states[1].context.count, equals(1));
      expect(states[2].context.count, equals(2));
    });

    test('asStream includes current state first', () async {
      final actor = machine.createActor();
      actor.start();
      actor.send(IncrementEvent()); // count = 1

      final stream = actor.asStream();
      final first = await stream.first;

      expect(first.context.count, equals(1));
    });
  });

  group('StateMachineActor.toString', () {
    test('returns readable format', () {
      final actor = machine.createActor();
      final str = actor.toString();
      expect(str, contains('StateMachineActor'));
      expect(str, contains('counter'));
    });
  });
}

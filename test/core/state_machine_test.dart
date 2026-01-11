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

class ResetEvent extends CounterEvent {
  @override
  String get type => 'RESET';
}

void main() {
  group('StateMachine.create', () {
    test('creates machine with correct id', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('active')
          ..state('active', (s) {}),
        id: 'counter',
      );

      expect(machine.id, equals('counter'));
    });

    test('throws if no context provided', () {
      expect(
        () => StateMachine.create<CounterContext, CounterEvent>(
          (m) => m
            ..initial('active')
            ..state('active', (s) {}),
          id: 'counter',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws if no initial state provided', () {
      expect(
        () => StateMachine.create<CounterContext, CounterEvent>(
          (m) => m
            ..context(const CounterContext())
            ..state('active', (s) {}),
          id: 'counter',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws if no states provided', () {
      expect(
        () => StateMachine.create<CounterContext, CounterEvent>(
          (m) => m
            ..context(const CounterContext())
            ..initial('active'),
          id: 'counter',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws if initial state not found', () {
      expect(
        () => StateMachine.create<CounterContext, CounterEvent>(
          (m) => m
            ..context(const CounterContext())
            ..initial('nonexistent')
            ..state('active', (s) {}),
          id: 'counter',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('StateMachine.initialState', () {
    test('returns snapshot in initial state', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext(count: 5))
          ..initial('idle')
          ..state('idle', (s) {})
          ..state('active', (s) {}),
        id: 'counter',
      );

      final initial = machine.initialState;
      expect(initial.matches('idle'), isTrue);
      expect(initial.context.count, equals(5));
      expect(initial.done, isFalse);
    });

    test('initial event is InitEvent', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('idle')
          ..state('idle', (s) {}),
        id: 'counter',
      );

      expect(machine.initialState.event, isA<InitEvent>());
    });
  });

  group('StateMachine.transition', () {
    late StateMachine<CounterContext, CounterEvent> machine;

    setUp(() {
      machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('idle')
          ..state('idle', (s) => s..on<IncrementEvent>('active'))
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
              )
              ..on<ResetEvent>(
                'idle',
                actions: [(ctx, _) => ctx.copyWith(count: 0)],
              ),
          ),
        id: 'counter',
      );
    });

    test('transitions to new state', () {
      final initial = machine.initialState;
      final next = machine.transition(initial, IncrementEvent());

      expect(next.matches('active'), isTrue);
    });

    test('executes actions during transition', () {
      var state = machine.initialState;
      state = machine.transition(state, IncrementEvent()); // idle -> active
      state = machine.transition(
        state,
        IncrementEvent(),
      ); // active -> active with count+1

      expect(state.context.count, equals(1));
    });

    test('guards prevent transition', () {
      var state = machine.initialState;
      state = machine.transition(state, IncrementEvent()); // idle -> active

      // count is 0, decrement should be blocked
      final next = machine.transition(state, DecrementEvent());
      expect(next.context.count, equals(0));
      expect(next, equals(state)); // No change
    });

    test('guard allows transition when condition met', () {
      var state = machine.initialState;
      state = machine.transition(state, IncrementEvent()); // idle -> active
      state = machine.transition(state, IncrementEvent()); // count = 1
      state = machine.transition(state, DecrementEvent()); // count = 0

      expect(state.context.count, equals(0));
    });

    test('unhandled event returns same state', () {
      final initial = machine.initialState; // idle
      final next = machine.transition(initial, DecrementEvent());

      expect(next, equals(initial));
    });

    test('does not transition from final state', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('active')
          ..state('active', (s) => s..on<ResetEvent>('done'))
          ..state('done', (s) => s..final_()),
        id: 'counter',
      );

      var state = machine.initialState;
      state = machine.transition(state, ResetEvent()); // -> done
      expect(state.done, isTrue);

      // Cannot transition from final state
      final next = machine.transition(state, IncrementEvent());
      expect(next, equals(state));
    });
  });

  group('StateMachine.withContext', () {
    test('creates new machine with different context', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext(count: 0))
          ..initial('idle')
          ..state('idle', (s) {}),
        id: 'counter',
      );

      final newMachine = machine.withContext(const CounterContext(count: 100));

      expect(newMachine.initialContext.count, equals(100));
      expect(machine.initialContext.count, equals(0)); // Original unchanged
    });
  });

  group('StateMachine.createActor', () {
    test('creates actor from machine', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('idle')
          ..state('idle', (s) {}),
        id: 'counter',
      );

      final actor = machine.createActor();
      expect(actor, isA<StateMachineActor<CounterContext, CounterEvent>>());
      expect(actor.machine, equals(machine));
    });

    test('creates actor with initial snapshot', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('idle')
          ..state('idle', (s) => s..on<IncrementEvent>('active'))
          ..state('active', (s) {}),
        id: 'counter',
      );

      const customSnapshot = StateSnapshot<CounterContext>(
        value: AtomicStateValue('active'),
        context: CounterContext(count: 50),
      );

      final actor = machine.createActor(initialSnapshot: customSnapshot);
      expect(actor.snapshot.matches('active'), isTrue);
      expect(actor.context.count, equals(50));
    });
  });

  group('StateMachine with entry/exit actions', () {
    test('executes entry actions when entering state', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('idle')
          ..state('idle', (s) => s..on<IncrementEvent>('active'))
          ..state(
            'active',
            (s) => s..entry([(ctx, _) => ctx.copyWith(count: ctx.count + 10)]),
          ),
        id: 'counter',
      );

      var state = machine.initialState;
      state = machine.transition(state, IncrementEvent());

      expect(state.context.count, equals(10));
    });

    test('executes exit actions when leaving state', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('idle')
          ..state(
            'idle',
            (s) => s
              ..on<IncrementEvent>('active')
              ..exit([(ctx, _) => ctx.copyWith(count: ctx.count + 5)]),
          )
          ..state('active', (s) {}),
        id: 'counter',
      );

      var state = machine.initialState;
      state = machine.transition(state, IncrementEvent());

      expect(state.context.count, equals(5));
    });

    test('executes exit, transition, entry actions in order', () {
      final log = <String>[];

      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('idle')
          ..state(
            'idle',
            (s) => s
              ..on<IncrementEvent>(
                'active',
                actions: [
                  (ctx, _) {
                    log.add('transition');
                    return ctx;
                  },
                ],
              )
              ..exit([
                (ctx, _) {
                  log.add('exit');
                  return ctx;
                },
              ]),
          )
          ..state(
            'active',
            (s) => s
              ..entry([
                (ctx, _) {
                  log.add('entry');
                  return ctx;
                },
              ]),
          ),
        id: 'counter',
      );

      var state = machine.initialState;
      state = machine.transition(state, IncrementEvent());

      expect(log, equals(['exit', 'transition', 'entry']));
    });
  });

  group('StateMachine.toString', () {
    test('returns readable format', () {
      final machine = StateMachine.create<CounterContext, CounterEvent>(
        (m) => m
          ..context(const CounterContext())
          ..initial('idle')
          ..state('idle', (s) {}),
        id: 'myMachine',
      );

      expect(machine.toString(), equals('StateMachine(myMachine)'));
    });
  });
}

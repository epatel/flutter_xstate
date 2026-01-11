import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class AppContext {
  final int value;
  const AppContext({this.value = 0});

  AppContext copyWith({int? value}) => AppContext(value: value ?? this.value);
}

// Test events
sealed class AppEvent extends XEvent {}

class NextEvent extends AppEvent {
  @override
  String get type => 'NEXT';
}

class BackEvent extends AppEvent {
  @override
  String get type => 'BACK';
}

class SubmitEvent extends AppEvent {
  @override
  String get type => 'SUBMIT';
}

void main() {
  group('MachineBuilder', () {
    test('builds machine with context and initial state', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext(value: 10))
          ..initial('idle')
          ..state('idle', (s) {}),
        id: 'app',
      );

      expect(machine.id, equals('app'));
      expect(machine.initialContext.value, equals(10));
      expect(machine.initialState.matches('idle'), isTrue);
    });

    test('builds machine with multiple states', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('a')
          ..state('a', (s) => s..on<NextEvent>('b'))
          ..state('b', (s) => s..on<NextEvent>('c'))
          ..state('c', (s) {}),
        id: 'app',
      );

      var state = machine.initialState;
      expect(state.matches('a'), isTrue);

      state = machine.transition(state, NextEvent());
      expect(state.matches('b'), isTrue);

      state = machine.transition(state, NextEvent());
      expect(state.matches('c'), isTrue);
    });
  });

  group('StateBuilder', () {
    test('builds atomic state by default', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('idle')
          ..state('idle', (s) {}),
        id: 'app',
      );

      expect(machine.root.states['idle']?.isAtomic, isTrue);
    });

    test('builds compound state with initial child', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('traffic')
          ..state(
            'traffic',
            (s) => s
              ..initial('green')
              ..state('green', (s) => s..on<NextEvent>('yellow'))
              ..state('yellow', (s) => s..on<NextEvent>('red'))
              ..state('red', (s) => s..on<NextEvent>('green')),
          ),
        id: 'app',
      );

      expect(machine.root.states['traffic']?.isCompound, isTrue);
      expect(machine.initialState.matches('traffic'), isTrue);
      expect(machine.initialState.matches('green'), isTrue);
    });

    test('builds final state', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('active')
          ..state('active', (s) => s..on<NextEvent>('done'))
          ..state('done', (s) => s..final_(output: 'completed')),
        id: 'app',
      );

      expect(machine.root.states['done']?.isFinal, isTrue);
      expect(machine.root.states['done']?.output, equals('completed'));
    });

    test('builds parallel state', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('player')
          ..state(
            'player',
            (s) => s
              ..parallel()
              ..state(
                'audio',
                (s) => s
                  ..initial('playing')
                  ..state('playing', (s) {})
                  ..state('muted', (s) {}),
              )
              ..state(
                'video',
                (s) => s
                  ..initial('visible')
                  ..state('visible', (s) {})
                  ..state('hidden', (s) {}),
              ),
          ),
        id: 'app',
      );

      expect(machine.root.states['player']?.isParallel, isTrue);
    });

    test('adds transitions with on<Event>', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('idle')
          ..state(
            'idle',
            (s) => s
              ..on<NextEvent>('active')
              ..on<SubmitEvent>('submitted'),
          )
          ..state('active', (s) {})
          ..state('submitted', (s) {}),
        id: 'app',
      );

      var state = machine.initialState;
      state = machine.transition(state, NextEvent());
      expect(state.matches('active'), isTrue);

      state = machine.transition(state, SubmitEvent());
      // active has no transition for SubmitEvent, so stays in active
      expect(state.matches('active'), isTrue);
    });

    test('adds guarded transitions', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('active')
          ..state(
            'active',
            (s) => s..on<NextEvent>('next', guard: (ctx, _) => ctx.value > 0),
          )
          ..state('next', (s) {}),
        id: 'app',
      );

      final state = machine.initialState;
      final next = machine.transition(state, NextEvent());

      // Guard fails, stays in same state
      expect(next.matches('active'), isTrue);
    });

    test('adds transition actions', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('active')
          ..state(
            'active',
            (s) => s
              ..on<NextEvent>(
                'active',
                actions: [(ctx, _) => ctx.copyWith(value: ctx.value + 1)],
              ),
          ),
        id: 'app',
      );

      var state = machine.initialState;
      state = machine.transition(state, NextEvent());

      expect(state.context.value, equals(1));
    });

    test('adds entry actions', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('idle')
          ..state('idle', (s) => s..on<NextEvent>('active'))
          ..state(
            'active',
            (s) => s..entry([(ctx, _) => ctx.copyWith(value: 100)]),
          ),
        id: 'app',
      );

      var state = machine.initialState;
      state = machine.transition(state, NextEvent());

      expect(state.context.value, equals(100));
    });

    test('adds exit actions', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('idle')
          ..state(
            'idle',
            (s) => s
              ..on<NextEvent>('active')
              ..exit([(ctx, _) => ctx.copyWith(value: 50)]),
          )
          ..state('active', (s) {}),
        id: 'app',
      );

      var state = machine.initialState;
      state = machine.transition(state, NextEvent());

      expect(state.context.value, equals(50));
    });

    test('onMultiple adds multiple guarded transitions', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext(value: 5))
          ..initial('check')
          ..state(
            'check',
            (s) => s
              ..onMultiple<SubmitEvent>([
                (
                  target: 'high',
                  guard: (ctx, _) => ctx.value > 10,
                  actions: null,
                ),
                (target: 'low', guard: null, actions: null), // Default fallback
              ]),
          )
          ..state('high', (s) {})
          ..state('low', (s) {}),
        id: 'app',
      );

      // value is 5, should go to 'low' (fallback)
      var state = machine.initialState;
      state = machine.transition(state, SubmitEvent());
      expect(state.matches('low'), isTrue);
    });

    test('self-transition with null target', () {
      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('active')
          ..state(
            'active',
            (s) => s
              ..on<NextEvent>(
                null,
                actions: [(ctx, _) => ctx.copyWith(value: ctx.value + 1)],
              ),
          ),
        id: 'app',
      );

      var state = machine.initialState;
      state = machine.transition(state, NextEvent());

      expect(state.matches('active'), isTrue);
      expect(state.context.value, equals(1));
    });

    test('internal transition skips entry/exit', () {
      final log = <String>[];

      final machine = StateMachine.create<AppContext, AppEvent>(
        (m) => m
          ..context(const AppContext())
          ..initial('active')
          ..state(
            'active',
            (s) => s
              ..entry([
                (ctx, _) {
                  log.add('entry');
                  return ctx;
                },
              ])
              ..exit([
                (ctx, _) {
                  log.add('exit');
                  return ctx;
                },
              ])
              ..on<NextEvent>(
                null,
                internal: true,
                actions: [
                  (ctx, _) {
                    log.add('action');
                    return ctx.copyWith(value: ctx.value + 1);
                  },
                ],
              ),
          ),
        id: 'app',
      );

      var state = machine.initialState;
      log.clear(); // Clear any initial entry actions

      state = machine.transition(state, NextEvent());

      expect(log, equals(['action'])); // No entry/exit
      expect(state.context.value, equals(1));
    });
  });
}

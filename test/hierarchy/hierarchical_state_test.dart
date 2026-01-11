import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context that tracks action order
class TestContext {
  final List<String> log;
  final int count;

  const TestContext({this.log = const [], this.count = 0});

  TestContext addLog(String message) =>
      TestContext(log: [...log, message], count: count);

  TestContext copyWith({List<String>? log, int? count}) =>
      TestContext(log: log ?? this.log, count: count ?? this.count);
}

// Test events
sealed class TestEvent extends XEvent {}

class NextEvent extends TestEvent {
  @override
  String get type => 'NEXT';
}

class BackEvent extends TestEvent {
  @override
  String get type => 'BACK';
}

class DeepEvent extends TestEvent {
  @override
  String get type => 'DEEP';
}

class HistoryEvent extends TestEvent {
  @override
  String get type => 'HISTORY';
}

void main() {
  group('Compound States', () {
    test('transitions to initial child state', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('parent')
          ..state(
            'parent',
            (s) => s
              ..initial('child1')
              ..state('child1', (s) => s..on<NextEvent>('child2'))
              ..state('child2', (s) {}),
          ),
        id: 'test',
      );

      final initial = machine.initialState;
      expect(initial.matches('parent'), isTrue);
      expect(initial.matches('child1'), isTrue);
      expect(initial.matches('parent.child1'), isTrue);
    });

    test('transitions between sibling states', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('parent')
          ..state(
            'parent',
            (s) => s
              ..initial('child1')
              ..state('child1', (s) => s..on<NextEvent>('child2'))
              ..state('child2', (s) => s..on<NextEvent>('child3'))
              ..state('child3', (s) {}),
          ),
        id: 'test',
      );

      var state = machine.initialState;
      expect(state.matches('child1'), isTrue);

      state = machine.transition(state, NextEvent());
      expect(state.matches('child2'), isTrue);
      expect(state.matches('parent'), isTrue);

      state = machine.transition(state, NextEvent());
      expect(state.matches('child3'), isTrue);
    });

    test('deeply nested states work correctly', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('level1')
          ..state(
            'level1',
            (s) => s
              ..initial('level2')
              ..state(
                'level2',
                (s) => s
                  ..initial('level3')
                  ..state(
                    'level3',
                    (s) => s
                      ..initial('level4')
                      ..state('level4', (s) {}),
                  ),
              ),
          ),
        id: 'test',
      );

      final initial = machine.initialState;
      expect(initial.matches('level1'), isTrue);
      expect(initial.matches('level2'), isTrue);
      expect(initial.matches('level3'), isTrue);
      expect(initial.matches('level4'), isTrue);
    });
  });

  group('Entry/Exit Ordering', () {
    test('enters parent before child', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('outside')
          ..state('outside', (s) => s..on<NextEvent>('parent'))
          ..state(
            'parent',
            (s) => s
              ..entry([(ctx, _) => ctx.addLog('enter:parent')])
              ..initial('child')
              ..state(
                'child',
                (s) => s..entry([(ctx, _) => ctx.addLog('enter:child')]),
              ),
          ),
        id: 'test',
      );

      var state = machine.initialState;
      state = machine.transition(state, NextEvent());

      expect(state.context.log, equals(['enter:parent', 'enter:child']));
    });

    test('exits child before parent', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('parent')
          ..state(
            'parent',
            (s) => s
              ..exit([(ctx, _) => ctx.addLog('exit:parent')])
              ..initial('child')
              ..state(
                'child',
                (s) => s
                  ..exit([(ctx, _) => ctx.addLog('exit:child')])
                  ..on<NextEvent>('outside'),
              ),
          )
          ..state('outside', (s) {}),
        id: 'test',
      );

      var state = machine.initialState;
      state = machine.transition(state, NextEvent());

      expect(state.context.log, equals(['exit:child', 'exit:parent']));
    });

    test('sibling transition exits then enters at same level', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('parent')
          ..state(
            'parent',
            (s) => s
              ..entry([(ctx, _) => ctx.addLog('enter:parent')])
              ..exit([(ctx, _) => ctx.addLog('exit:parent')])
              ..initial('child1')
              ..state(
                'child1',
                (s) => s
                  ..entry([(ctx, _) => ctx.addLog('enter:child1')])
                  ..exit([(ctx, _) => ctx.addLog('exit:child1')])
                  ..on<NextEvent>('child2'),
              )
              ..state(
                'child2',
                (s) => s
                  ..entry([(ctx, _) => ctx.addLog('enter:child2')])
                  ..exit([(ctx, _) => ctx.addLog('exit:child2')]),
              ),
          ),
        id: 'test',
      );

      var state = machine.initialState;
      // Clear entry logs from initialization
      state = state.copyWith(context: const TestContext());

      state = machine.transition(state, NextEvent());

      // Only child states should exit/enter, not parent (LCA optimization)
      expect(state.context.log, equals(['exit:child1', 'enter:child2']));
    });

    test('cross-level transition has correct ordering', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('a')
          ..state(
            'a',
            (s) => s
              ..exit([(ctx, _) => ctx.addLog('exit:a')])
              ..initial('a1')
              ..state(
                'a1',
                (s) => s
                  ..exit([(ctx, _) => ctx.addLog('exit:a1')])
                  ..on<NextEvent>('b'),
              ),
          )
          ..state(
            'b',
            (s) => s
              ..entry([(ctx, _) => ctx.addLog('enter:b')])
              ..initial('b1')
              ..state(
                'b1',
                (s) => s..entry([(ctx, _) => ctx.addLog('enter:b1')]),
              ),
          ),
        id: 'test',
      );

      var state = machine.initialState;
      state = state.copyWith(context: const TestContext());

      state = machine.transition(state, NextEvent());

      // Exit innermost to outermost, then enter outermost to innermost
      expect(
        state.context.log,
        equals(['exit:a1', 'exit:a', 'enter:b', 'enter:b1']),
      );
    });
  });

  group('Internal Transitions', () {
    test('internal transition does not execute entry/exit', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('state')
          ..state(
            'state',
            (s) => s
              ..entry([(ctx, _) => ctx.addLog('entry')])
              ..exit([(ctx, _) => ctx.addLog('exit')])
              ..on<NextEvent>(
                null,
                internal: true,
                actions: [(ctx, _) => ctx.addLog('action')],
              ),
          ),
        id: 'test',
      );

      var state = machine.initialState;
      state = state.copyWith(context: const TestContext());

      state = machine.transition(state, NextEvent());

      expect(state.context.log, equals(['action']));
    });
  });

  group('State Matching', () {
    test('matches works with dot notation for nested states', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('app')
          ..state(
            'app',
            (s) => s
              ..initial('dashboard')
              ..state(
                'dashboard',
                (s) => s
                  ..initial('overview')
                  ..state('overview', (s) {})
                  ..state('details', (s) {}),
              )
              ..state('settings', (s) {}),
          ),
        id: 'test',
      );

      final state = machine.initialState;

      expect(state.matches('app'), isTrue);
      expect(state.matches('dashboard'), isTrue);
      expect(state.matches('overview'), isTrue);
      expect(state.matches('app.dashboard'), isTrue);
      expect(state.matches('app.dashboard.overview'), isTrue);

      expect(state.matches('settings'), isFalse);
      expect(state.matches('details'), isFalse);
      expect(state.matches('app.settings'), isFalse);
    });
  });

  group('Transitions from Parent', () {
    test('parent transition takes precedence when child has no handler', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('parent')
          ..state(
            'parent',
            (s) => s
              ..on<BackEvent>('outside')
              ..initial('child')
              ..state(
                'child',
                (s) => s..on<NextEvent>('child'), // Only handles NextEvent
              ),
          )
          ..state('outside', (s) {}),
        id: 'test',
      );

      var state = machine.initialState;
      expect(state.matches('child'), isTrue);

      // BackEvent is handled by parent
      state = machine.transition(state, BackEvent());
      expect(state.matches('outside'), isTrue);
    });

    test('child transition takes precedence over parent', () {
      final machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('parent')
          ..state(
            'parent',
            (s) => s
              ..on<NextEvent>(
                'outside',
                actions: [(ctx, _) => ctx.addLog('parent-handler')],
              )
              ..initial('child')
              ..state(
                'child',
                (s) => s
                  ..on<NextEvent>(
                    'sibling',
                    actions: [(ctx, _) => ctx.addLog('child-handler')],
                  ),
              )
              ..state('sibling', (s) {}),
          )
          ..state('outside', (s) {}),
        id: 'test',
      );

      var state = machine.initialState;
      state = machine.transition(state, NextEvent());

      // Child handler takes precedence
      expect(state.context.log, contains('child-handler'));
      expect(state.context.log, isNot(contains('parent-handler')));
      expect(state.matches('sibling'), isTrue);
    });
  });
}

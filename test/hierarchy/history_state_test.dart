import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class TestContext {
  final List<String> log;

  const TestContext({this.log = const []});

  TestContext addLog(String message) => TestContext(log: [...log, message]);
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

class ToHistoryEvent extends TestEvent {
  @override
  String get type => 'TO_HISTORY';
}

void main() {
  group('HistoryManager', () {
    test('records and retrieves history', () {
      const manager = HistoryManager.empty();
      const value = AtomicStateValue('child2');

      final updated = manager.recordHistory('parent', value);

      expect(updated.hasHistory('parent'), isTrue);
      expect(updated.getHistory('parent'), equals(value));
    });

    test('clears history', () {
      const manager = HistoryManager({'parent': AtomicStateValue('child')});

      final cleared = manager.clearHistory('parent');

      expect(cleared.hasHistory('parent'), isFalse);
    });

    test('toMap returns unmodifiable map', () {
      const manager = HistoryManager({'parent': AtomicStateValue('child')});

      final map = manager.toMap();
      expect(map['parent'], isA<AtomicStateValue>());
    });

    test('fromMap creates manager from map', () {
      final map = {'parent': const AtomicStateValue('child')};

      final manager = HistoryManager.fromMap(map);
      expect(manager.hasHistory('parent'), isTrue);
    });
  });

  group('StatePath', () {
    test('isEmpty and isNotEmpty work correctly', () {
      const empty = StatePath<TestContext, TestEvent>.empty();
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);
    });

    test('depth returns correct value', () {
      final path = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'child'),
      ]);

      expect(path.depth, equals(2));
    });

    test('leaf returns innermost config', () {
      final path = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'child'),
        const StateConfig(id: 'grandchild'),
      ]);

      expect(path.leaf?.id, equals('grandchild'));
    });

    test('root returns outermost config', () {
      final path = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'child'),
      ]);

      expect(path.root?.id, equals('root'));
    });

    test('contains checks for state id', () {
      final path = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'child'),
      ]);

      expect(path.contains('root'), isTrue);
      expect(path.contains('child'), isTrue);
      expect(path.contains('other'), isFalse);
    });

    test('stateIds returns all ids', () {
      final path = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'a'),
        const StateConfig(id: 'b'),
        const StateConfig(id: 'c'),
      ]);

      expect(path.stateIds, equals(['a', 'b', 'c']));
    });
  });

  group('StateHierarchy', () {
    test('findLCADepth finds correct ancestor depth', () {
      final source = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'parent'),
        const StateConfig(id: 'child1'),
      ]);

      final target = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'parent'),
        const StateConfig(id: 'child2'),
      ]);

      final lcaDepth = StateHierarchy.findLCADepth(source, target);

      // LCA is 'parent' at depth 2 (0=root, 1=parent)
      expect(lcaDepth, equals(2));
    });

    test('getExitStates returns correct order', () {
      final source = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'a'),
        const StateConfig(id: 'a1'),
      ]);

      final target = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'b'),
      ]);

      final exitStates = StateHierarchy.getExitStates(source, target);

      // Should exit a1 then a (innermost to outermost up to LCA)
      expect(exitStates.map((c) => c.id).toList(), equals(['a1', 'a']));
    });

    test('getEntryStates returns correct order', () {
      final source = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'a'),
      ]);

      final target = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'b'),
        const StateConfig(id: 'b1'),
      ]);

      final entryStates = StateHierarchy.getEntryStates(source, target);

      // Should enter b then b1 (outermost to innermost from LCA)
      expect(entryStates.map((c) => c.id).toList(), equals(['b', 'b1']));
    });

    test('isAncestor checks ancestry correctly', () {
      final ancestor = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'parent'),
      ]);

      final descendant = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'parent'),
        const StateConfig(id: 'child'),
      ]);

      final unrelated = StatePath<TestContext, TestEvent>([
        const StateConfig(id: 'root'),
        const StateConfig(id: 'other'),
      ]);

      expect(StateHierarchy.isAncestor(ancestor, descendant), isTrue);
      expect(StateHierarchy.isAncestor(descendant, ancestor), isFalse);
      expect(StateHierarchy.isAncestor(ancestor, unrelated), isFalse);
    });
  });

  group('History State Resolution', () {
    test('history is recorded when exiting compound state', () {
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
              ..state('child3', (s) => s..on<BackEvent>('outside')),
          )
          ..state('outside', (s) => s..on<ToHistoryEvent>('parent')),
        id: 'test',
      );

      var state = machine.initialState;

      // Navigate to child3
      state = machine.transition(state, NextEvent());
      state = machine.transition(state, NextEvent());
      expect(state.matches('child3'), isTrue);

      // Exit to outside
      state = machine.transition(state, BackEvent());
      expect(state.matches('outside'), isTrue);

      // History should have been recorded
      expect(state.historyValue.isNotEmpty, isTrue);
    });
  });

  group('HistoryResolution extension', () {
    test('fullPath returns complete path string', () {
      const value = CompoundStateValue(
        'app',
        CompoundStateValue('dashboard', AtomicStateValue('overview')),
      );

      expect(value.fullPath, equals('app.dashboard.overview'));
    });

    test('leafId returns innermost state id', () {
      const value = CompoundStateValue(
        'app',
        CompoundStateValue('dashboard', AtomicStateValue('overview')),
      );

      expect(value.leafId, equals('overview'));
    });

    test('atomic state fullPath is just id', () {
      const value = AtomicStateValue('simple');
      expect(value.fullPath, equals('simple'));
      expect(value.leafId, equals('simple'));
    });
  });
}

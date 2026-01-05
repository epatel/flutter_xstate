import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

class TestContext {
  final int count;
  const TestContext({this.count = 0});

  TestContext copyWith({int? count}) =>
      TestContext(count: count ?? this.count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestContext && count == other.count;

  @override
  int get hashCode => count.hashCode;
}

void main() {
  group('StateSnapshot', () {
    test('stores value and context', () {
      const snapshot = StateSnapshot<TestContext>(
        value: AtomicStateValue('idle'),
        context: TestContext(count: 5),
      );

      expect(snapshot.value, isA<AtomicStateValue>());
      expect((snapshot.value as AtomicStateValue).id, equals('idle'));
      expect(snapshot.context.count, equals(5));
    });

    test('matches delegates to state value', () {
      const snapshot = StateSnapshot<TestContext>(
        value: AtomicStateValue('idle'),
        context: TestContext(),
      );

      expect(snapshot.matches('idle'), isTrue);
      expect(snapshot.matches('active'), isFalse);
    });

    test('activeStates delegates to state value', () {
      const snapshot = StateSnapshot<TestContext>(
        value: CompoundStateValue('app', AtomicStateValue('home')),
        context: TestContext(),
      );

      expect(snapshot.activeStates, contains('app'));
      expect(snapshot.activeStates, contains('app.home'));
    });

    test('done defaults to false', () {
      const snapshot = StateSnapshot<TestContext>(
        value: AtomicStateValue('idle'),
        context: TestContext(),
      );

      expect(snapshot.done, isFalse);
      expect(snapshot.canTransition, isTrue);
    });

    test('done state prevents transitions', () {
      const snapshot = StateSnapshot<TestContext>(
        value: AtomicStateValue('complete'),
        context: TestContext(),
        done: true,
      );

      expect(snapshot.done, isTrue);
      expect(snapshot.canTransition, isFalse);
    });

    test('output is available for final states', () {
      const snapshot = StateSnapshot<TestContext>(
        value: AtomicStateValue('complete'),
        context: TestContext(),
        done: true,
        output: 'success',
      );

      expect(snapshot.output, equals('success'));
    });

    test('copyWith creates new snapshot with updated values', () {
      const original = StateSnapshot<TestContext>(
        value: AtomicStateValue('idle'),
        context: TestContext(count: 0),
      );

      final updated = original.copyWith(
        value: const AtomicStateValue('active'),
        context: const TestContext(count: 1),
      );

      expect(updated.matches('active'), isTrue);
      expect(updated.context.count, equals(1));
      // Original unchanged
      expect(original.matches('idle'), isTrue);
      expect(original.context.count, equals(0));
    });

    test('copyWith preserves unchanged values', () {
      const original = StateSnapshot<TestContext>(
        value: AtomicStateValue('idle'),
        context: TestContext(count: 5),
        done: true,
        output: 'result',
      );

      final updated = original.copyWith(
        value: const AtomicStateValue('new'),
      );

      expect(updated.matches('new'), isTrue);
      expect(updated.context.count, equals(5));
      expect(updated.done, isTrue);
      expect(updated.output, equals('result'));
    });

    test('equality works correctly', () {
      const snapshot1 = StateSnapshot<TestContext>(
        value: AtomicStateValue('idle'),
        context: TestContext(count: 0),
      );
      const snapshot2 = StateSnapshot<TestContext>(
        value: AtomicStateValue('idle'),
        context: TestContext(count: 0),
      );
      const snapshot3 = StateSnapshot<TestContext>(
        value: AtomicStateValue('active'),
        context: TestContext(count: 0),
      );

      expect(snapshot1, equals(snapshot2));
      expect(snapshot1, isNot(equals(snapshot3)));
    });

    test('event is stored', () {
      final event = SimpleEvent('TEST');
      final snapshot = StateSnapshot<TestContext>(
        value: const AtomicStateValue('idle'),
        context: const TestContext(),
        event: event,
      );

      expect(snapshot.event, equals(event));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

class TestContext {
  final int count;
  const TestContext({this.count = 0});

  TestContext copyWith({int? count}) => TestContext(count: count ?? this.count);
}

class TestEvent extends XEvent {
  @override
  String get type => 'TEST';
}

void main() {
  group('Transition', () {
    test('stores target', () {
      const transition = Transition<TestContext, TestEvent>(target: 'active');
      expect(transition.target, equals('active'));
    });

    test('null target means self-transition', () {
      const transition = Transition<TestContext, TestEvent>(target: null);
      expect(transition.target, isNull);
    });

    test('isEnabled returns true when no guard', () {
      const transition = Transition<TestContext, TestEvent>(target: 'active');

      expect(transition.isEnabled(const TestContext(), TestEvent()), isTrue);
    });

    test('isEnabled checks guard condition', () {
      final transition = Transition<TestContext, TestEvent>(
        target: 'active',
        guard: (ctx, _) => ctx.count > 0,
      );

      expect(
        transition.isEnabled(const TestContext(count: 0), TestEvent()),
        isFalse,
      );
      expect(
        transition.isEnabled(const TestContext(count: 1), TestEvent()),
        isTrue,
      );
    });

    test('executeActions updates context', () {
      final transition = Transition<TestContext, TestEvent>(
        target: 'active',
        actions: [(ctx, _) => ctx.copyWith(count: ctx.count + 1)],
      );

      final result = transition.executeActions(
        const TestContext(count: 0),
        TestEvent(),
      );

      expect(result.count, equals(1));
    });

    test('executeActions chains multiple actions', () {
      final transition = Transition<TestContext, TestEvent>(
        target: 'active',
        actions: [
          (ctx, _) => ctx.copyWith(count: ctx.count + 1),
          (ctx, _) => ctx.copyWith(count: ctx.count * 2),
          (ctx, _) => ctx.copyWith(count: ctx.count + 10),
        ],
      );

      final result = transition.executeActions(
        const TestContext(count: 5),
        TestEvent(),
      );

      // (5 + 1) = 6, * 2 = 12, + 10 = 22
      expect(result.count, equals(22));
    });

    test('internal flag defaults to false', () {
      const transition = Transition<TestContext, TestEvent>(target: 'active');
      expect(transition.internal, isFalse);
    });

    test('internal flag can be set', () {
      const transition = Transition<TestContext, TestEvent>(
        target: null,
        internal: true,
      );
      expect(transition.internal, isTrue);
    });

    test('description is stored', () {
      const transition = Transition<TestContext, TestEvent>(
        target: 'active',
        description: 'Transition to active state',
      );
      expect(transition.description, equals('Transition to active state'));
    });

    test('toString provides readable output', () {
      const transition = Transition<TestContext, TestEvent>(target: 'active');
      expect(transition.toString(), contains('active'));
    });
  });

  group('TransitionResult', () {
    test('stores from/to values and context', () {
      const result = TransitionResult<TestContext>(
        fromValue: AtomicStateValue('idle'),
        toValue: AtomicStateValue('active'),
        context: TestContext(count: 5),
        changed: true,
      );

      expect((result.fromValue as AtomicStateValue).id, equals('idle'));
      expect((result.toValue as AtomicStateValue).id, equals('active'));
      expect(result.context.count, equals(5));
      expect(result.changed, isTrue);
    });

    test('noChange factory sets changed to false', () {
      const result = TransitionResult<TestContext>.noChange(
        fromValue: AtomicStateValue('idle'),
        context: TestContext(),
      );

      expect(result.changed, isFalse);
      expect(result.fromValue, equals(result.toValue));
    });

    test('toString shows transition info', () {
      const result = TransitionResult<TestContext>(
        fromValue: AtomicStateValue('idle'),
        toValue: AtomicStateValue('active'),
        context: TestContext(),
        changed: true,
      );

      final str = result.toString();
      expect(str, contains('idle'));
      expect(str, contains('active'));
    });

    test('toString shows no change', () {
      const result = TransitionResult<TestContext>.noChange(
        fromValue: AtomicStateValue('idle'),
        context: TestContext(),
      );

      expect(result.toString(), contains('no change'));
    });
  });
}

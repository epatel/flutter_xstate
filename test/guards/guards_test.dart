import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class TestContext {
  final int count;
  final bool isValid;
  final String? name;
  final List<String> items;

  const TestContext({
    this.count = 0,
    this.isValid = false,
    this.name,
    this.items = const [],
  });
}

// Test events
sealed class TestEvent extends XEvent {}

class TestActionEvent extends TestEvent {
  @override
  String get type => 'TEST';
}

void main() {
  group('guard', () {
    test('evaluates condition', () {
      final g = guard<TestContext, TestEvent>(
        (ctx, _) => ctx.count > 5,
      );

      expect(
        g.evaluate(const TestContext(count: 10), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 3), TestActionEvent()),
        isFalse,
      );
    });

    test('can access event data', () {
      final g = guard<TestContext, TestEvent>(
        (ctx, event) => event.type == 'TEST',
      );

      expect(
        g.evaluate(const TestContext(), TestActionEvent()),
        isTrue,
      );
    });

    test('toCallback returns function', () {
      final g = guard<TestContext, TestEvent>((ctx, _) => ctx.isValid);

      final callback = g.toCallback();
      expect(callback(const TestContext(isValid: true), TestActionEvent()), isTrue);
    });
  });

  group('InlineGuard', () {
    test('stores description', () {
      final g = guard<TestContext, TestEvent>(
        (ctx, _) => true,
        description: 'always true',
      );

      expect(g.description, equals('always true'));
    });
  });

  group('AlwaysGuard', () {
    test('always returns true', () {
      const g = AlwaysGuard<TestContext, TestEvent>();

      expect(g.evaluate(const TestContext(), TestActionEvent()), isTrue);
      expect(g.evaluate(const TestContext(count: 100), TestActionEvent()), isTrue);
    });

    test('has correct description', () {
      const g = AlwaysGuard<TestContext, TestEvent>();
      expect(g.description, equals('always'));
    });
  });

  group('NeverGuard', () {
    test('always returns false', () {
      const g = NeverGuard<TestContext, TestEvent>();

      expect(g.evaluate(const TestContext(), TestActionEvent()), isFalse);
      expect(g.evaluate(const TestContext(isValid: true), TestActionEvent()), isFalse);
    });

    test('has correct description', () {
      const g = NeverGuard<TestContext, TestEvent>();
      expect(g.description, equals('never'));
    });
  });

  group('and', () {
    test('returns true only if all guards are true', () {
      final g = and<TestContext, TestEvent>([
        guard((ctx, _) => ctx.count > 0),
        guard((ctx, _) => ctx.isValid),
      ]);

      expect(
        g.evaluate(const TestContext(count: 5, isValid: true), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 5, isValid: false), TestActionEvent()),
        isFalse,
      );
      expect(
        g.evaluate(const TestContext(count: 0, isValid: true), TestActionEvent()),
        isFalse,
      );
    });

    test('short-circuits on first false', () {
      var secondCalled = false;
      final g = and<TestContext, TestEvent>([
        guard((ctx, _) => false),
        guard((ctx, _) {
          secondCalled = true;
          return true;
        }),
      ]);

      g.evaluate(const TestContext(), TestActionEvent());
      expect(secondCalled, isFalse);
    });
  });

  group('or', () {
    test('returns true if any guard is true', () {
      final g = or<TestContext, TestEvent>([
        guard((ctx, _) => ctx.count > 10),
        guard((ctx, _) => ctx.isValid),
      ]);

      expect(
        g.evaluate(const TestContext(count: 5, isValid: true), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 20, isValid: false), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 5, isValid: false), TestActionEvent()),
        isFalse,
      );
    });

    test('short-circuits on first true', () {
      var secondCalled = false;
      final g = or<TestContext, TestEvent>([
        guard((ctx, _) => true),
        guard((ctx, _) {
          secondCalled = true;
          return false;
        }),
      ]);

      g.evaluate(const TestContext(), TestActionEvent());
      expect(secondCalled, isFalse);
    });
  });

  group('not', () {
    test('negates guard result', () {
      final g = not<TestContext, TestEvent>(
        guard((ctx, _) => ctx.count > 0),
      );

      expect(
        g.evaluate(const TestContext(count: 0), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 5), TestActionEvent()),
        isFalse,
      );
    });

    test('has correct description', () {
      final g = not<TestContext, TestEvent>(
        guard((ctx, _) => true, description: 'myGuard'),
      );
      expect(g.description, equals('!myGuard'));
    });
  });

  group('xor', () {
    test('returns true if exactly one guard is true', () {
      final g = xor<TestContext, TestEvent>([
        guard((ctx, _) => ctx.count > 5),
        guard((ctx, _) => ctx.isValid),
      ]);

      // One true
      expect(
        g.evaluate(const TestContext(count: 10, isValid: false), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 0, isValid: true), TestActionEvent()),
        isTrue,
      );
      // Both true
      expect(
        g.evaluate(const TestContext(count: 10, isValid: true), TestActionEvent()),
        isFalse,
      );
      // Neither true
      expect(
        g.evaluate(const TestContext(count: 0, isValid: false), TestActionEvent()),
        isFalse,
      );
    });
  });

  group('equalsValue', () {
    test('checks equality', () {
      final g = equalsValue<TestContext, TestEvent, int>(
        (ctx) => ctx.count,
        5,
      );

      expect(
        g.evaluate(const TestContext(count: 5), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 10), TestActionEvent()),
        isFalse,
      );
    });

    test('works with strings', () {
      final g = equalsValue<TestContext, TestEvent, String?>(
        (ctx) => ctx.name,
        'Alice',
      );

      expect(
        g.evaluate(const TestContext(name: 'Alice'), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(name: 'Bob'), TestActionEvent()),
        isFalse,
      );
    });
  });

  group('isGreaterThan', () {
    test('checks if value is greater', () {
      final g = isGreaterThan<TestContext, TestEvent>(
        (ctx) => ctx.count,
        5,
      );

      expect(
        g.evaluate(const TestContext(count: 10), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 5), TestActionEvent()),
        isFalse,
      );
      expect(
        g.evaluate(const TestContext(count: 3), TestActionEvent()),
        isFalse,
      );
    });
  });

  group('isLessThan', () {
    test('checks if value is less', () {
      final g = isLessThan<TestContext, TestEvent>(
        (ctx) => ctx.count,
        10,
      );

      expect(
        g.evaluate(const TestContext(count: 5), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 10), TestActionEvent()),
        isFalse,
      );
      expect(
        g.evaluate(const TestContext(count: 15), TestActionEvent()),
        isFalse,
      );
    });
  });

  group('inRange', () {
    test('checks if value is within range', () {
      final g = inRange<TestContext, TestEvent>(
        (ctx) => ctx.count,
        0,
        10,
      );

      expect(
        g.evaluate(const TestContext(count: 5), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 0), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: 10), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(count: -1), TestActionEvent()),
        isFalse,
      );
      expect(
        g.evaluate(const TestContext(count: 11), TestActionEvent()),
        isFalse,
      );
    });
  });

  group('isNullValue', () {
    test('checks if value is null', () {
      final g = isNullValue<TestContext, TestEvent>(
        (ctx) => ctx.name,
      );

      expect(
        g.evaluate(const TestContext(name: null), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(name: 'Alice'), TestActionEvent()),
        isFalse,
      );
    });
  });

  group('isNotNullValue', () {
    test('checks if value is not null', () {
      final g = isNotNullValue<TestContext, TestEvent>(
        (ctx) => ctx.name,
      );

      expect(
        g.evaluate(const TestContext(name: 'Alice'), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(name: null), TestActionEvent()),
        isFalse,
      );
    });
  });

  group('isEmptyCollection', () {
    test('checks if collection is empty', () {
      final g = isEmptyCollection<TestContext, TestEvent>(
        (ctx) => ctx.items,
      );

      expect(
        g.evaluate(const TestContext(items: []), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(items: ['a']), TestActionEvent()),
        isFalse,
      );
    });
  });

  group('isNotEmptyCollection', () {
    test('checks if collection is not empty', () {
      final g = isNotEmptyCollection<TestContext, TestEvent>(
        (ctx) => ctx.items,
      );

      expect(
        g.evaluate(const TestContext(items: ['a', 'b']), TestActionEvent()),
        isTrue,
      );
      expect(
        g.evaluate(const TestContext(items: []), TestActionEvent()),
        isFalse,
      );
    });
  });

  group('complex combinations', () {
    test('nested combinators work correctly', () {
      // (count > 0 AND isValid) OR (count > 100)
      final g = or<TestContext, TestEvent>([
        and([
          guard((ctx, _) => ctx.count > 0),
          guard((ctx, _) => ctx.isValid),
        ]),
        guard((ctx, _) => ctx.count > 100),
      ]);

      // count > 0 AND isValid
      expect(
        g.evaluate(const TestContext(count: 5, isValid: true), TestActionEvent()),
        isTrue,
      );
      // count > 100 (even without isValid)
      expect(
        g.evaluate(const TestContext(count: 150, isValid: false), TestActionEvent()),
        isTrue,
      );
      // Neither condition
      expect(
        g.evaluate(const TestContext(count: 5, isValid: false), TestActionEvent()),
        isFalse,
      );
    });
  });
}

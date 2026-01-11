import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class TestContext {
  final int count;
  final String message;
  const TestContext({this.count = 0, this.message = ''});

  TestContext copyWith({int? count, String? message}) =>
      TestContext(count: count ?? this.count, message: message ?? this.message);
}

// Test events
sealed class TestEvent extends XEvent {}

class IncrementEvent extends TestEvent {
  @override
  String get type => 'INCREMENT';
}

class MessageEvent extends TestEvent {
  final String text;
  MessageEvent(this.text);
  @override
  String get type => 'MESSAGE';
}

void main() {
  group('assign', () {
    test('updates context', () {
      final action = assign<TestContext, TestEvent>(
        (ctx, _) => ctx.copyWith(count: ctx.count + 1),
      );

      final result = action.execute(
        const TestContext(count: 5),
        IncrementEvent(),
      );

      expect(result.context.count, equals(6));
    });

    test('has correct description', () {
      final action = assign<TestContext, TestEvent>(
        (ctx, _) => ctx.copyWith(count: 0),
      );
      expect(action.description, equals('assign'));
    });

    test('can access event data', () {
      final action = assign<TestContext, TestEvent>((ctx, event) {
        if (event is MessageEvent) {
          return ctx.copyWith(message: event.text);
        }
        return ctx;
      });

      final result = action.execute(const TestContext(), MessageEvent('hello'));

      expect(result.context.message, equals('hello'));
    });
  });

  group('raise', () {
    test('returns raised event', () {
      final action = raise<TestContext, TestEvent>(IncrementEvent());

      final result = action.execute(const TestContext(), IncrementEvent());

      expect(result.raisedEvents.length, equals(1));
      expect(result.raisedEvents.first, isA<IncrementEvent>());
    });

    test('does not modify context', () {
      final action = raise<TestContext, TestEvent>(IncrementEvent());

      final result = action.execute(
        const TestContext(count: 5),
        IncrementEvent(),
      );

      expect(result.context.count, equals(5));
    });

    test('has correct description', () {
      final action = raise<TestContext, TestEvent>(IncrementEvent());
      expect(action.description, contains('INCREMENT'));
    });
  });

  group('raiseFrom', () {
    test('computes event from context', () {
      final action = raiseFrom<TestContext, TestEvent>(
        (ctx, _) => MessageEvent('count is ${ctx.count}'),
      );

      final result = action.execute(
        const TestContext(count: 42),
        IncrementEvent(),
      );

      expect(result.raisedEvents.length, equals(1));
      final event = result.raisedEvents.first as MessageEvent;
      expect(event.text, equals('count is 42'));
    });
  });

  group('log', () {
    test('returns log message', () {
      final action = log<TestContext, TestEvent>(
        (ctx, _) => 'Count: ${ctx.count}',
      );

      final result = action.execute(
        const TestContext(count: 10),
        IncrementEvent(),
      );

      expect(result.logMessages.length, equals(1));
      expect(result.logMessages.first, equals('Count: 10'));
    });

    test('does not modify context', () {
      final action = log<TestContext, TestEvent>((_, _) => 'test');

      final result = action.execute(
        const TestContext(count: 5),
        IncrementEvent(),
      );

      expect(result.context.count, equals(5));
    });
  });

  group('logMessage', () {
    test('returns static message', () {
      final action = logMessage<TestContext, TestEvent>('Hello World');

      final result = action.execute(const TestContext(), IncrementEvent());

      expect(result.logMessages.first, equals('Hello World'));
    });
  });

  group('sendTo', () {
    test('returns send action', () {
      final action = sendTo<TestContext, TestEvent>(
        'parentActor',
        IncrementEvent(),
      );

      final result = action.execute(const TestContext(), IncrementEvent());

      expect(result.sendToActions.length, equals(1));
      expect(result.sendToActions.first.actorId, equals('parentActor'));
      expect(result.sendToActions.first.event, isA<IncrementEvent>());
    });

    test('does not modify context', () {
      final action = sendTo<TestContext, TestEvent>('actor', IncrementEvent());

      final result = action.execute(
        const TestContext(count: 5),
        IncrementEvent(),
      );

      expect(result.context.count, equals(5));
    });
  });

  group('sendToFrom', () {
    test('computes event from context', () {
      final action = sendToFrom<TestContext, TestEvent>(
        'actor',
        (ctx, _) => MessageEvent('result: ${ctx.count}'),
      );

      final result = action.execute(
        const TestContext(count: 99),
        IncrementEvent(),
      );

      final event = result.sendToActions.first.event as MessageEvent;
      expect(event.text, equals('result: 99'));
    });
  });

  group('pure', () {
    test('executes side effect', () {
      var sideEffectCalled = false;

      final action = pure<TestContext, TestEvent>((_, _) {
        sideEffectCalled = true;
      });

      action.execute(const TestContext(), IncrementEvent());

      expect(sideEffectCalled, isTrue);
    });

    test('does not modify context', () {
      final action = pure<TestContext, TestEvent>((_, _) {});

      final result = action.execute(
        const TestContext(count: 5),
        IncrementEvent(),
      );

      expect(result.context.count, equals(5));
    });
  });

  group('sequence', () {
    test('executes actions in order', () {
      final action = sequence<TestContext, TestEvent>([
        assign((ctx, _) => ctx.copyWith(count: ctx.count + 1)),
        assign((ctx, _) => ctx.copyWith(count: ctx.count * 2)),
        assign((ctx, _) => ctx.copyWith(count: ctx.count + 10)),
      ]);

      final result = action.execute(
        const TestContext(count: 5),
        IncrementEvent(),
      );

      // (5 + 1) = 6, * 2 = 12, + 10 = 22
      expect(result.context.count, equals(22));
    });

    test('combines side effects', () {
      final action = sequence<TestContext, TestEvent>([
        log((ctx, _) => 'Start: ${ctx.count}'),
        assign((ctx, _) => ctx.copyWith(count: ctx.count + 1)),
        log((ctx, _) => 'End: ${ctx.count}'),
      ]);

      final result = action.execute(
        const TestContext(count: 0),
        IncrementEvent(),
      );

      expect(result.logMessages.length, equals(2));
      expect(result.logMessages[0], equals('Start: 0'));
      expect(result.logMessages[1], equals('End: 1'));
    });
  });

  group('when', () {
    test('executes action when condition is true', () {
      final action = when<TestContext, TestEvent>(
        (ctx, _) => ctx.count > 0,
        assign((ctx, _) => ctx.copyWith(count: ctx.count * 2)),
      );

      final result = action.execute(
        const TestContext(count: 5),
        IncrementEvent(),
      );

      expect(result.context.count, equals(10));
    });

    test('skips action when condition is false', () {
      final action = when<TestContext, TestEvent>(
        (ctx, _) => ctx.count > 0,
        assign((ctx, _) => ctx.copyWith(count: ctx.count * 2)),
      );

      final result = action.execute(
        const TestContext(count: 0),
        IncrementEvent(),
      );

      expect(result.context.count, equals(0));
    });
  });

  group('ActionResult', () {
    test('merge combines results', () {
      final result1 = ActionResult<TestContext, TestEvent>(
        context: const TestContext(count: 1),
        logMessages: ['msg1'],
        raisedEvents: [IncrementEvent()],
      );

      final result2 = ActionResult<TestContext, TestEvent>(
        context: const TestContext(count: 2),
        logMessages: ['msg2'],
        raisedEvents: [IncrementEvent()],
      );

      final merged = result1.merge(result2);

      // Context comes from second result
      expect(merged.context.count, equals(2));
      // Side effects are combined
      expect(merged.logMessages.length, equals(2));
      expect(merged.raisedEvents.length, equals(2));
    });
  });
}

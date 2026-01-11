import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class TestContext {
  final int count;
  const TestContext({this.count = 0});
  TestContext copyWith({int? count}) => TestContext(count: count ?? this.count);
}

// Test events
sealed class TestEvent extends XEvent {}

class IncrementEvent extends TestEvent {
  @override
  String get type => 'INCREMENT';
}

void main() {
  late StateMachine<TestContext, TestEvent> childMachine;

  setUp(() {
    childMachine = StateMachine.create<TestContext, TestEvent>(
      (m) => m
        ..context(const TestContext())
        ..initial('idle')
        ..state(
          'idle',
          (s) => s
            ..on<IncrementEvent>(
              'idle',
              actions: [(ctx, _) => ctx.copyWith(count: ctx.count + 1)],
            ),
        ),
      id: 'child',
    );
  });

  group('SpawnConfig', () {
    test('creates config with static id', () {
      final config = SpawnConfig<TestContext, TestEvent>(
        id: 'child',
        machine: childMachine,
      );

      expect(config.id, equals('child'));
      expect(config.machine, equals(childMachine));
      expect(config.autoStart, isTrue);
    });

    test('creates config with autoStart false', () {
      final config = SpawnConfig<TestContext, TestEvent>(
        id: 'child',
        machine: childMachine,
        autoStart: false,
      );

      expect(config.autoStart, isFalse);
    });

    test('creates config with dynamic id', () {
      final config = SpawnConfig<TestContext, TestEvent>.dynamic(
        id: (ctx, event) => 'child-${(ctx as TestContext).count}',
        machine: childMachine,
      );

      final id = config.resolveId(
        const TestContext(count: 42),
        IncrementEvent(),
      );
      expect(id, equals('child-42'));
    });

    test('resolveId returns static id when no dynamic id', () {
      final config = SpawnConfig<TestContext, TestEvent>(
        id: 'static-child',
        machine: childMachine,
      );

      final id = config.resolveId(const TestContext(), IncrementEvent());
      expect(id, equals('static-child'));
    });
  });

  group('SpawnAction', () {
    test('execute returns SpawnActionResult with context and config', () {
      final config = SpawnConfig<TestContext, TestEvent>(
        id: 'child',
        machine: childMachine,
      );

      final action =
          SpawnAction<TestContext, TestEvent, TestContext, TestEvent>(config);
      final result = action.execute(
        const TestContext(count: 5),
        IncrementEvent(),
      );

      expect(result, isA<SpawnActionResult>());
      expect(result.context.count, equals(5));

      final spawnResult =
          result
              as SpawnActionResult<
                TestContext,
                TestEvent,
                TestContext,
                TestEvent
              >;
      expect(spawnResult.spawnConfig, equals(config));
    });

    test('description includes id', () {
      final config = SpawnConfig<TestContext, TestEvent>(
        id: 'my-child',
        machine: childMachine,
      );

      final action =
          SpawnAction<TestContext, TestEvent, TestContext, TestEvent>(config);
      expect(action.description, equals('spawn(my-child)'));
    });
  });

  group('spawn helper function', () {
    test('creates SpawnAction', () {
      final config = SpawnConfig<TestContext, TestEvent>(
        id: 'child',
        machine: childMachine,
      );

      final action = spawn<TestContext, TestEvent, TestContext, TestEvent>(
        config,
      );
      expect(action, isA<SpawnAction>());
    });
  });

  group('StopChildAction', () {
    test('execute returns StopChildActionResult', () {
      final action = StopChildAction<TestContext, TestEvent>('child-to-stop');
      final result = action.execute(const TestContext(), IncrementEvent());

      expect(result, isA<StopChildActionResult>());
      final stopResult =
          result as StopChildActionResult<TestContext, TestEvent>;
      expect(stopResult.childId, equals('child-to-stop'));
    });

    test('resolveId returns static id', () {
      final action = StopChildAction<TestContext, TestEvent>('static-id');
      expect(
        action.resolveId(const TestContext(), IncrementEvent()),
        equals('static-id'),
      );
    });

    test('dynamic resolveId uses callback', () {
      final action = StopChildAction<TestContext, TestEvent>.dynamic(
        (ctx, event) => 'child-${ctx.count}',
      );
      expect(
        action.resolveId(const TestContext(count: 10), IncrementEvent()),
        equals('child-10'),
      );
    });

    test('description includes id', () {
      final action = StopChildAction<TestContext, TestEvent>('child');
      expect(action.description, equals('stopChild(child)'));
    });
  });

  group('stopChild helper function', () {
    test('creates StopChildAction with static id', () {
      final action = stopChild<TestContext, TestEvent>('child');
      expect(action, isA<StopChildAction>());
      expect(
        action.resolveId(const TestContext(), IncrementEvent()),
        equals('child'),
      );
    });
  });

  group('stopChildDynamic helper function', () {
    test('creates StopChildAction with dynamic id', () {
      final action = stopChildDynamic<TestContext, TestEvent>(
        (ctx, _) => 'child-${ctx.count}',
      );
      expect(action, isA<StopChildAction>());
      expect(
        action.resolveId(const TestContext(count: 5), IncrementEvent()),
        equals('child-5'),
      );
    });
  });

  group('SendToChildAction', () {
    test('execute returns SendToChildActionResult', () {
      final action = SendToChildAction<TestContext, TestEvent, TestEvent>(
        childId: 'child',
        event: IncrementEvent(),
      );
      final result = action.execute(const TestContext(), IncrementEvent());

      expect(result, isA<SendToChildActionResult>());
      final sendResult =
          result as SendToChildActionResult<TestContext, TestEvent, TestEvent>;
      expect(sendResult.childId, equals('child'));
      expect(sendResult.childEvent, isA<IncrementEvent>());
    });

    test('resolveEvent returns static event', () {
      final event = IncrementEvent();
      final action = SendToChildAction<TestContext, TestEvent, TestEvent>(
        childId: 'child',
        event: event,
      );
      expect(
        action.resolveEvent(const TestContext(), IncrementEvent()),
        equals(event),
      );
    });

    test('dynamic resolveEvent uses callback', () {
      final action =
          SendToChildAction<TestContext, TestEvent, TestEvent>.dynamic(
            childId: 'child',
            eventFromContext: (ctx, _) => IncrementEvent(),
          );
      expect(
        action.resolveEvent(const TestContext(), IncrementEvent()),
        isA<IncrementEvent>(),
      );
    });

    test('description includes child id', () {
      final action = SendToChildAction<TestContext, TestEvent, TestEvent>(
        childId: 'my-child',
        event: IncrementEvent(),
      );
      expect(action.description, equals('sendToChild(my-child)'));
    });
  });

  group('sendToChild helper function', () {
    test('creates SendToChildAction', () {
      final action = sendToChild<TestContext, TestEvent, TestEvent>(
        childId: 'child',
        event: IncrementEvent(),
      );
      expect(action, isA<SendToChildAction>());
    });
  });

  group('ActorLifecycleHandler', () {
    test('creates handler with callbacks', () {
      final handler =
          ActorLifecycleHandler<TestContext, TestEvent, TestContext, TestEvent>(
            onDone: (ctx, ref) => ctx.copyWith(count: 99),
            onError: (ctx, error, stackTrace) => ctx.copyWith(count: -1),
          );

      expect(handler.onDone, isNotNull);
      expect(handler.onError, isNotNull);
    });

    test('creates handler with no callbacks', () {
      const handler =
          ActorLifecycleHandler<
            TestContext,
            TestEvent,
            TestContext,
            TestEvent
          >();
      expect(handler.onDone, isNull);
      expect(handler.onError, isNull);
    });
  });
}

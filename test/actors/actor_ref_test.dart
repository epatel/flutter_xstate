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

class StopEvent extends TestEvent {
  @override
  String get type => 'STOP';
}

void main() {
  group('MachineActorRef', () {
    late StateMachine<TestContext, TestEvent> machine;

    setUp(() {
      machine = StateMachine.create<TestContext, TestEvent>(
        (m) => m
          ..context(const TestContext())
          ..initial('active')
          ..state('active', (s) => s
            ..on<IncrementEvent>('active', actions: [
              (ctx, _) => ctx.copyWith(count: ctx.count + 1),
            ])
            ..on<StopEvent>('done')
          )
          ..state('done', (s) => s..final_()),
        id: 'test',
      );
    });

    test('creates ref with id and actor', () {
      final actor = machine.createActor();
      final ref = MachineActorRef<TestContext, TestEvent>(
        id: 'child',
        actor: actor,
      );

      expect(ref.id, equals('child'));
      expect(ref.actor, equals(actor));
    });

    test('isRunning returns correct state', () {
      final actor = machine.createActor();
      final ref = MachineActorRef<TestContext, TestEvent>(
        id: 'child',
        actor: actor,
      );

      expect(ref.isRunning, isFalse); // Not started yet
      actor.start();
      expect(ref.isRunning, isTrue);
      ref.stop();
      expect(ref.isRunning, isFalse);
    });

    test('send forwards events to actor', () {
      final actor = machine.createActor();
      final ref = MachineActorRef<TestContext, TestEvent>(
        id: 'child',
        actor: actor,
      );

      actor.start();
      ref.send(IncrementEvent());
      expect(ref.snapshot.context.count, equals(1));
    });

    test('stop stops the actor', () {
      final actor = machine.createActor();
      final ref = MachineActorRef<TestContext, TestEvent>(
        id: 'child',
        actor: actor,
      );

      actor.start();
      ref.stop();
      expect(ref.isRunning, isFalse);
    });

    test('matches delegates to actor', () {
      final actor = machine.createActor();
      final ref = MachineActorRef<TestContext, TestEvent>(
        id: 'child',
        actor: actor,
      );

      actor.start();
      expect(ref.matches('active'), isTrue);
      expect(ref.matches('done'), isFalse);
    });

    test('status stream emits stopped when actor completes', () async {
      final actor = machine.createActor();
      final ref = MachineActorRef<TestContext, TestEvent>(
        id: 'child',
        actor: actor,
      );

      actor.start();

      final statuses = <ActorStatus>[];
      ref.status.listen(statuses.add);

      ref.stop();

      await Future.delayed(Duration.zero);

      expect(statuses, contains(ActorStatus.stopped));
    });
  });

  group('CallbackActorRef', () {
    test('creates ref with id', () {
      final ref = CallbackActorRef<String, TestEvent>(id: 'callback');

      expect(ref.id, equals('callback'));
      expect(ref.isRunning, isTrue);
    });

    test('send calls onReceive', () {
      final received = <TestEvent>[];
      final ref = CallbackActorRef<String, TestEvent>(
        id: 'callback',
        onReceive: received.add,
      );

      ref.send(IncrementEvent());
      expect(received.length, equals(1));
      expect(received.first, isA<IncrementEvent>());
    });

    test('stop calls onStop and marks as not running', () {
      var stopped = false;
      final ref = CallbackActorRef<String, TestEvent>(
        id: 'callback',
        onStop: () => stopped = true,
      );

      expect(ref.isRunning, isTrue);
      ref.stop();
      expect(stopped, isTrue);
      expect(ref.isRunning, isFalse);
    });

    test('does not send after stop', () {
      final received = <TestEvent>[];
      final ref = CallbackActorRef<String, TestEvent>(
        id: 'callback',
        onReceive: received.add,
      );

      ref.stop();
      ref.send(IncrementEvent());
      expect(received, isEmpty);
    });
  });

  group('ActorStatus', () {
    test('has all expected values', () {
      expect(ActorStatus.values, containsAll([
        ActorStatus.starting,
        ActorStatus.running,
        ActorStatus.stopping,
        ActorStatus.stopped,
        ActorStatus.error,
      ]));
    });
  });
}

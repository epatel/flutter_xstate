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
  late StateMachine<TestContext, TestEvent> machine;

  setUp(() {
    machine = StateMachine.create<TestContext, TestEvent>(
      (m) => m
        ..context(const TestContext())
        ..initial('active')
        ..state(
          'active',
          (s) => s
            ..on<IncrementEvent>(
              'active',
              actions: [(ctx, _) => ctx.copyWith(count: ctx.count + 1)],
            )
            ..on<StopEvent>('done'),
        )
        ..state('done', (s) => s..final_()),
      id: 'test',
    );
  });

  group('ActorSystem', () {
    test('starts empty', () {
      final system = ActorSystem();
      expect(system.actorCount, equals(0));
      expect(system.actorIds, isEmpty);
    });

    test('spawn creates and registers actor', () {
      final system = ActorSystem();

      final ref = system.spawn<TestContext, TestEvent>(
        id: 'child',
        machine: machine,
      );

      expect(system.hasActor('child'), isTrue);
      expect(system.actorCount, equals(1));
      expect(ref.id, equals('child'));
      expect(ref.isRunning, isTrue); // autoStart is true by default
    });

    test('spawn with autoStart false does not start actor', () {
      final system = ActorSystem();

      final ref = system.spawn<TestContext, TestEvent>(
        id: 'child',
        machine: machine,
        autoStart: false,
      );

      expect(ref.actor.started, isFalse);
    });

    test('spawn throws if id already exists', () {
      final system = ActorSystem();

      system.spawn<TestContext, TestEvent>(id: 'child', machine: machine);

      expect(
        () =>
            system.spawn<TestContext, TestEvent>(id: 'child', machine: machine),
        throwsStateError,
      );
    });

    test('getActor returns actor by id', () {
      final system = ActorSystem();

      system.spawn<TestContext, TestEvent>(id: 'child', machine: machine);

      final ref = system.getActor<TestEvent>('child');
      expect(ref, isNotNull);
      expect(ref!.id, equals('child'));
    });

    test('getActor returns null for unknown id', () {
      final system = ActorSystem();
      expect(system.getActor<TestEvent>('unknown'), isNull);
    });

    test('stopActor stops actor and removes from registry', () async {
      final system = ActorSystem();

      system.spawn<TestContext, TestEvent>(id: 'child', machine: machine);

      expect(system.hasActor('child'), isTrue);
      system.stopActor('child');

      // Wait for status update to propagate
      await Future.delayed(Duration.zero);

      expect(system.hasActor('child'), isFalse);
    });

    test('sendTo sends event to actor', () {
      final system = ActorSystem();

      final ref = system.spawn<TestContext, TestEvent>(
        id: 'child',
        machine: machine,
      );

      expect(ref.snapshot.context.count, equals(0));
      final sent = system.sendTo<TestEvent>('child', IncrementEvent());
      expect(sent, isTrue);
      expect(ref.snapshot.context.count, equals(1));
    });

    test('sendTo returns false for unknown actor', () {
      final system = ActorSystem();
      final sent = system.sendTo<TestEvent>('unknown', IncrementEvent());
      expect(sent, isFalse);
    });

    test('parent-child relationships are tracked', () {
      final system = ActorSystem();

      system.spawn<TestContext, TestEvent>(id: 'parent', machine: machine);

      system.spawn<TestContext, TestEvent>(
        id: 'child',
        machine: machine,
        parentId: 'parent',
      );

      expect(system.getChildren('parent'), contains('child'));
      expect(system.getParent('child'), equals('parent'));
    });

    test('stopping parent stops children', () async {
      final system = ActorSystem();

      system.spawn<TestContext, TestEvent>(id: 'parent', machine: machine);

      system.spawn<TestContext, TestEvent>(
        id: 'child',
        machine: machine,
        parentId: 'parent',
      );

      system.stopActor('parent');

      await Future.delayed(Duration.zero);

      expect(system.hasActor('parent'), isFalse);
      expect(system.hasActor('child'), isFalse);
    });

    test('dispose stops all actors', () async {
      final system = ActorSystem();

      system.spawn<TestContext, TestEvent>(id: 'actor1', machine: machine);

      system.spawn<TestContext, TestEvent>(id: 'actor2', machine: machine);

      expect(system.actorCount, equals(2));

      system.dispose();

      await Future.delayed(Duration.zero);

      expect(system.actorCount, equals(0));
    });

    test('notifies listeners on actor changes', () {
      final system = ActorSystem();
      var notified = 0;
      system.addListener(() => notified++);

      system.spawn<TestContext, TestEvent>(id: 'child', machine: machine);

      expect(notified, greaterThan(0));
    });
  });

  group('ActorSystemAccess extension', () {
    test('system getter returns null by default', () {
      final actor = machine.createActor();
      expect(actor.system, isNull);
    });

    test('system setter assigns system', () {
      final actor = machine.createActor();
      final system = ActorSystem();

      actor.system = system;
      expect(actor.system, equals(system));
    });
  });
}

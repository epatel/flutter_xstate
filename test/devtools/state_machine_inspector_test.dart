import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_xstate/flutter_xstate.dart';

// Test context
class CounterContext {
  final int count;
  const CounterContext({this.count = 0});
  CounterContext copyWith({int? count}) =>
      CounterContext(count: count ?? this.count);
}

// Test events
sealed class CounterEvent extends XEvent {}

class IncrementEvent extends CounterEvent {
  @override
  String get type => 'INCREMENT';
}

class DecrementEvent extends CounterEvent {
  @override
  String get type => 'DECREMENT';
}

class ResetEvent extends CounterEvent {
  @override
  String get type => 'RESET';
}

void main() {
  late StateMachine<CounterContext, CounterEvent> machine;
  late StateMachineActor<CounterContext, CounterEvent> actor;

  setUp(() {
    machine = StateMachine.create<CounterContext, CounterEvent>(
      (m) => m
        ..context(const CounterContext())
        ..initial('active')
        ..state(
          'active',
          (s) => s
            ..on<IncrementEvent>(
              'active',
              actions: [(ctx, _) => ctx.copyWith(count: ctx.count + 1)],
            )
            ..on<DecrementEvent>(
              'active',
              actions: [(ctx, _) => ctx.copyWith(count: ctx.count - 1)],
            )
            ..on<ResetEvent>('idle'),
        )
        ..state('idle', (s) => s..on<IncrementEvent>('active')),
      id: 'counter',
    );

    actor = machine.createActor();
    actor.start();
  });

  tearDown(() {
    actor.dispose();
  });

  group('StateMachineInspector', () {
    test('attaches to actor', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      expect(inspector.isAttached, isTrue);
      expect(inspector.actor, equals(actor));

      inspector.dispose();
    });

    test('records transitions', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      actor.send(IncrementEvent());
      actor.send(IncrementEvent());

      expect(inspector.history.length, equals(2));
      expect(inspector.history.first.event?.type, equals('INCREMENT'));

      inspector.dispose();
    });

    test('captures previous and next state', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      actor.send(IncrementEvent());

      final record = inspector.history.first;
      expect(record.previousState.context.count, equals(0));
      expect(record.nextState.context.count, equals(1));

      inspector.dispose();
    });

    test('respects max history size', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>(
        config: const InspectorConfig(maxHistorySize: 3),
      );
      inspector.attach(actor);

      for (int i = 0; i < 5; i++) {
        actor.send(IncrementEvent());
      }

      expect(inspector.history.length, equals(3));

      inspector.dispose();
    });

    test('clears history', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      actor.send(IncrementEvent());
      expect(inspector.history.isNotEmpty, isTrue);

      inspector.clearHistory();
      expect(inspector.history, isEmpty);

      inspector.dispose();
    });

    test('provides current state', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      expect(inspector.currentState?.context.count, equals(0));

      actor.send(IncrementEvent());
      expect(inspector.currentState?.context.count, equals(1));

      inspector.dispose();
    });

    test('provides current state value', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      expect(inspector.currentState?.value.matches('active'), isTrue);

      actor.send(ResetEvent());
      expect(inspector.currentState?.value.matches('idle'), isTrue);

      inspector.dispose();
    });

    test('detaches properly', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      inspector.detach();

      expect(inspector.isAttached, isFalse);
      expect(inspector.actor, isNull);

      // Should not record after detach
      actor.send(IncrementEvent());
      expect(inspector.history, isEmpty);

      inspector.dispose();
    });

    test('notifies transition listeners', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      TransitionRecord<CounterContext>? capturedRecord;
      inspector.addTransitionListener((record) {
        capturedRecord = record;
      });

      actor.send(IncrementEvent());

      expect(capturedRecord, isNotNull);
      expect(capturedRecord!.event?.type, equals('INCREMENT'));

      inspector.dispose();
    });

    test('removes transition listeners', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      int callCount = 0;
      void listener(TransitionRecord<CounterContext> record) {
        callCount++;
      }

      inspector.addTransitionListener(listener);
      actor.send(IncrementEvent());
      expect(callCount, equals(1));

      inspector.removeTransitionListener(listener);
      actor.send(IncrementEvent());
      expect(callCount, equals(1)); // Should not increase

      inspector.dispose();
    });
  });

  group('Inspector filtering', () {
    test('filters by event type', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      actor.send(IncrementEvent());
      actor.send(DecrementEvent());
      actor.send(IncrementEvent());

      final increments = inspector.transitionsForEvent('INCREMENT');
      expect(increments.length, equals(2));

      final decrements = inspector.transitionsForEvent('DECREMENT');
      expect(decrements.length, equals(1));

      inspector.dispose();
    });

    test('filters by target state', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      actor.send(IncrementEvent());
      actor.send(ResetEvent());

      final toIdle = inspector.transitionsToState('idle');
      expect(toIdle.length, equals(1));

      inspector.dispose();
    });

    test('filters by source state', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      actor.send(IncrementEvent());
      actor.send(ResetEvent());
      actor.send(IncrementEvent());

      final fromActive = inspector.transitionsFromState('active');
      expect(fromActive.length, equals(2));

      inspector.dispose();
    });

    test('gets last N transitions', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      for (int i = 0; i < 5; i++) {
        actor.send(IncrementEvent());
      }

      final last3 = inspector.lastTransitions(3);
      expect(last3.length, equals(3));

      inspector.dispose();
    });
  });

  group('InspectorStats', () {
    test('computes statistics', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      actor.send(IncrementEvent());
      actor.send(IncrementEvent());
      actor.send(DecrementEvent());

      final stats = inspector.stats;

      expect(stats.totalTransitions, equals(3));
      expect(stats.eventCounts['INCREMENT'], equals(2));
      expect(stats.eventCounts['DECREMENT'], equals(1));
      // State counts use full state value string representation
      expect(stats.stateCounts.values.reduce((a, b) => a + b), equals(3));

      inspector.dispose();
    });
  });

  group('Mermaid diagram', () {
    test('generates diagram', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      actor.send(IncrementEvent());
      actor.send(ResetEvent());

      final diagram = inspector.generateMermaidDiagram();

      expect(diagram, contains('stateDiagram-v2'));
      // Diagram uses full state value representations
      expect(diagram, contains('INCREMENT'));
      expect(diagram, contains('RESET'));

      inspector.dispose();
    });
  });

  group('InspectorRegistry', () {
    test('registers and retrieves inspectors', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>();
      inspector.attach(actor);

      InspectorRegistry.instance.register('counter', inspector);

      final retrieved = InspectorRegistry.instance
          .get<CounterContext, CounterEvent>('counter');
      expect(retrieved, equals(inspector));

      InspectorRegistry.instance.unregister('counter');
      expect(InspectorRegistry.instance.ids, isEmpty);

      inspector.dispose();
    });
  });

  group('InspectorExtension', () {
    test('creates inspector via extension', () {
      final inspector = actor.inspect(
        config: const InspectorConfig(maxHistorySize: 50),
        registryId: 'test-counter',
      );

      expect(inspector.isAttached, isTrue);
      expect(InspectorRegistry.instance.ids, contains('test-counter'));

      InspectorRegistry.instance.clear();
    });
  });

  group('InspectorConfig', () {
    test('respects enabled = false', () {
      final inspector = StateMachineInspector<CounterContext, CounterEvent>(
        config: const InspectorConfig(enabled: false),
      );

      inspector.attach(actor);

      // Should not actually attach when disabled
      expect(inspector.isAttached, isFalse);

      inspector.dispose();
    });
  });
}
